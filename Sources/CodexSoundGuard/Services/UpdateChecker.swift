import AppKit
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var isChecking = false
    @Published private(set) var lastResult: UpdateCheckResult?

    private let currentVersion: AppVersion
    private let releaseURL = URL(string: "https://api.github.com/repos/whitewooood/codex-extra/releases/latest")!
    private let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    init(currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0") {
        self.currentVersion = AppVersion(currentVersion)
    }

    func checkAutomaticallyIfNeeded() {
        guard UserDefaults.standard.bool(forKey: AppDefaults.Key.automaticUpdateChecksEnabled) else {
            return
        }

        let lastCheck = UserDefaults.standard.double(forKey: AppDefaults.Key.lastUpdateCheckAt)
        guard Date().timeIntervalSince1970 - lastCheck >= automaticCheckInterval else {
            return
        }

        Task {
            await checkForUpdates(presentNoUpdateAlert: false, respectIgnoredVersion: true)
        }
    }

    func checkManually() {
        Task {
            await checkForUpdates(presentNoUpdateAlert: true, respectIgnoredVersion: false)
        }
    }

    private func checkForUpdates(presentNoUpdateAlert: Bool, respectIgnoredVersion: Bool) async {
        guard !isChecking else {
            return
        }

        isChecking = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppDefaults.Key.lastUpdateCheckAt)
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()

            guard release.isNewer(than: currentVersion) else {
                lastResult = .upToDate(version: currentVersion.description)
                if presentNoUpdateAlert {
                    showUpToDateAlert()
                }
                return
            }

            let ignoredVersion = UserDefaults.standard.string(forKey: AppDefaults.Key.ignoredUpdateVersion) ?? ""
            guard !respectIgnoredVersion || release.version.description != ignoredVersion else {
                lastResult = .ignored(version: release.version.description)
                return
            }

            lastResult = .updateAvailable(release)
            showUpdateAvailableAlert(release)
        } catch {
            lastResult = .failed(error.localizedDescription)
            if presentNoUpdateAlert {
                showFailureAlert(error)
            }
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CodexMonitorUpdateChecker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw UpdateCheckError.badResponse
        }

        return try JSONDecoder.githubReleaseDecoder.decode(GitHubRelease.self, from: data)
    }

    private func showUpdateAvailableAlert(_ release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(release.version)"
        alert.informativeText = updateMessage(for: release)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "稍后提醒")
        alert.addButton(withTitle: "忽略此版本")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(release.version.description, forKey: AppDefaults.Key.ignoredUpdateVersion)
        default:
            break
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本 \(currentVersion)。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showFailureAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func updateMessage(for release: GitHubRelease) -> String {
        var lines = [
            "当前版本 \(currentVersion)，最新版本 \(release.version)。",
            "发布页面会在浏览器中打开，仍由你手动下载和安装。"
        ]

        if let publishedAt = release.publishedAt {
            lines.append("发布时间：\(Self.dateFormatter.string(from: publishedAt))")
        }

        if let body = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            lines.append("")
            lines.append(String(body.prefix(700)))
        }

        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum UpdateCheckResult: Equatable {
    case updateAvailable(GitHubRelease)
    case upToDate(version: String)
    case ignored(version: String)
    case failed(String)
}

enum UpdateCheckError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "GitHub Releases 返回了异常响应。"
        }
    }
}

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?

    var version: AppVersion {
        AppVersion(tagName)
    }

    func isNewer(than version: AppVersion) -> Bool {
        self.version > version
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }
}

struct AppVersion: Comparable, CustomStringConvertible, Equatable {
    let rawValue: String
    private let components: [Int]

    init(_ rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
        self.rawValue = normalized.isEmpty ? "0.0.0" : normalized
        self.components = self.rawValue
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .split(separator: ".")
            .map { Int($0) ?? 0 } ?? [0]
    }

    var description: String {
        rawValue
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

private extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}

private extension JSONDecoder {
    static let githubReleaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
