import Foundation

enum LoginItemManager {
    private static let bundleID = "com.whitewood.codex-monitor"

    static var launchAgentPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(bundleID).plist")
            .path
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: launchAgentPath)
    }

    static func install() throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw LoginItemError.missingExecutable
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(bundleID)</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(executableURL.path)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """

        let url = URL(fileURLWithPath: launchAgentPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plist.write(to: url, atomically: true, encoding: .utf8)

        _ = try? runLaunchctl(arguments: ["bootout", guiDomain, launchAgentPath])
        try runLaunchctl(arguments: ["bootstrap", guiDomain, launchAgentPath])
        try runLaunchctl(arguments: ["enable", "\(guiDomain)/\(bundleID)"])
    }

    static func uninstall() throws {
        _ = try? runLaunchctl(arguments: ["bootout", guiDomain, launchAgentPath])
        try? FileManager.default.removeItem(atPath: launchAgentPath)
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
}

enum LoginItemError: Error, LocalizedError {
    case missingExecutable
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "找不到当前应用的可执行文件。"
        case .launchctlFailed(let output):
            return output.isEmpty ? "launchctl 执行失败。" : output
        }
    }
}
