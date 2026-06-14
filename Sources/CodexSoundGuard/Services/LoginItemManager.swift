import Foundation
import ServiceManagement

enum LoginItemManager {
    private static let bundleID = "com.whitewood.codex-monitor"

    static var launchAgentPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(bundleID).plist")
            .path
    }

    static var isInstalled: Bool {
        status.isInstalled
    }

    static var status: LoginItemStatus {
        if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
            return .enabled(kind: .systemLoginItem)
        }

        return launchAgentStatus()
    }

    static func install() throws {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                try removeLaunchAgentIfPresent()
                return
            } catch {
                if !canInstallLaunchAgentFallback {
                    throw LoginItemError.serviceManagementFailed(error.localizedDescription)
                }
            }
        }

        try installLaunchAgent()
    }

    static func uninstall() throws {
        var errors: [String] = []

        if #available(macOS 13.0, *), SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        do {
            try uninstallLaunchAgent()
        } catch {
            errors.append(error.localizedDescription)
        }

        if !errors.isEmpty {
            throw LoginItemError.uninstallFailed(errors.joined(separator: "\n"))
        }
    }

    private static func installLaunchAgent() throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw LoginItemError.missingExecutable
        }

        guard canInstallLaunchAgentFallback else {
            throw LoginItemError.unstableAppLocation
        }

        let plist: [String: Any] = [
            "Label": bundleID,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        let url = URL(fileURLWithPath: launchAgentPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)

        _ = try? runLaunchctl(arguments: ["bootout", guiDomain, launchAgentPath])
        try runLaunchctl(arguments: ["bootstrap", guiDomain, launchAgentPath])
        try runLaunchctl(arguments: ["enable", "\(guiDomain)/\(bundleID)"])
    }

    private static func uninstallLaunchAgent() throws {
        _ = try? runLaunchctl(arguments: ["bootout", guiDomain, launchAgentPath])
        try removeLaunchAgentIfPresent()
    }

    private static func removeLaunchAgentIfPresent() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            return
        }
        try FileManager.default.removeItem(atPath: launchAgentPath)
    }

    @discardableResult
    private static func runLaunchctl(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw LoginItemError.launchctlFailed(output)
        }
        return output
    }

    private static var guiDomain: String {
        "gui/\(getuid())"
    }

    private static func launchAgentStatus() -> LoginItemStatus {
        let url = URL(fileURLWithPath: launchAgentPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .disabled
        }

        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let arguments = plist["ProgramArguments"] as? [String],
            let executablePath = arguments.first,
            !executablePath.isEmpty
        else {
            return .stale(reason: "LaunchAgent 配置无法读取")
        }

        guard FileManager.default.fileExists(atPath: executablePath) else {
            return .stale(reason: "LaunchAgent 指向的 App 已不存在")
        }

        guard let currentExecutable = Bundle.main.executableURL?.standardizedFileURL.path else {
            return .enabled(kind: .launchAgent)
        }

        if URL(fileURLWithPath: executablePath).standardizedFileURL.path == currentExecutable {
            return .enabled(kind: .launchAgent)
        }

        return .stale(reason: "LaunchAgent 指向旧位置")
    }

    private static var canInstallLaunchAgentFallback: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else {
            return false
        }

        let path = bundleURL.path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL
            .path
        return path.hasPrefix("/Applications/") || path.hasPrefix("\(userApplications)/")
    }
}

enum LoginItemKind: Equatable {
    case systemLoginItem
    case launchAgent

    var title: String {
        switch self {
        case .systemLoginItem:
            return "系统登录项"
        case .launchAgent:
            return "LaunchAgent"
        }
    }
}

enum LoginItemStatus: Equatable {
    case disabled
    case enabled(kind: LoginItemKind)
    case stale(reason: String)

    var isInstalled: Bool {
        switch self {
        case .enabled:
            return true
        case .disabled, .stale:
            return false
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            return "未开启"
        case .enabled(let kind):
            return "\(kind.title) 已开启"
        case .stale(let reason):
            return "\(reason)，建议重新开启"
        }
    }
}

enum LoginItemError: Error, LocalizedError {
    case missingExecutable
    case serviceManagementFailed(String)
    case unstableAppLocation
    case launchctlFailed(String)
    case uninstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "找不到当前应用的可执行文件。"
        case .serviceManagementFailed(let output):
            return output.isEmpty ? "登录项注册失败。" : output
        case .unstableAppLocation:
            return "请先将 Codex Monitor.app 移到 Applications 或 ~/Applications 后再开启登录时启动。"
        case .launchctlFailed(let output):
            return output.isEmpty ? "launchctl 执行失败。" : output
        case .uninstallFailed(let output):
            return output.isEmpty ? "登录项移除失败。" : output
        }
    }
}
