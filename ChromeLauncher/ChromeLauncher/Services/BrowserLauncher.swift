import Foundation
import AppKit

/// 浏览器启动服务
class BrowserLauncher {
    static let shared = BrowserLauncher()

    private init() {}

    /// 启动结果
    enum LaunchResult {
        case success
        case browserNotInstalled
        case profileNotFound
        case launchFailed(Error)
    }

    /// 启动 Profile
    @discardableResult
    func launch(
        profile: Profile,
        withBrowser browserType: BrowserType? = nil,
        additionalArgs: [String] = []
    ) -> LaunchResult {
        let browser = browserType ?? profile.browserType

        // 检查浏览器是否安装
        guard browser.isInstalled else {
            return .browserNotInstalled
        }

        // 检查 Profile 目录是否存在
        guard FileManager.default.fileExists(atPath: profile.fullPath) else {
            return .profileNotFound
        }

        // 构建启动参数
        var arguments: [String] = []

        // 用户数据目录（如果使用非默认浏览器打开）
        if browserType != nil && browserType != profile.browserType {
            arguments.append("--user-data-dir=\(profile.browserType.dataDirectory)")
        }

        // Profile 目录
        arguments.append("--profile-directory=\(profile.directoryName)")

        // 启动配置参数
        arguments.append(contentsOf: profile.launchConfig.asArguments)

        // 额外参数
        arguments.append(contentsOf: additionalArgs)

        // 启动浏览器
        do {
            try launchBrowser(browser, arguments: arguments)
            return .success
        } catch {
            return .launchFailed(error)
        }
    }

    /// 使用指定参数启动浏览器
    func launchBrowser(_ browserType: BrowserType, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: browserType.executablePath)
        process.arguments = arguments

        try process.run()
    }

    /// 使用 open 命令启动（确保参数正确传递）
    func launchWithWorkspace(
        profile: Profile,
        withBrowser browserType: BrowserType? = nil,
        incognito: Bool = false,
        forceNewWindow: Bool = false
    ) async -> LaunchResult {
        let browser = browserType ?? profile.browserType

        guard browser.isInstalled else {
            return .browserNotInstalled
        }

        guard FileManager.default.fileExists(atPath: profile.fullPath) else {
            return .profileNotFound
        }

        // 检查 Profile 是否已经在运行
        let isRunning = ProfileScanner.shared.isProfileRunning(profile)

        // 如果已经运行且不强制新窗口，激活已有窗口
        if isRunning && !forceNewWindow && !incognito {
            return await activateExistingProfile(profile: profile, browser: browser)
        }

        // 构建参数
        var arguments: [String] = []

        // 用户数据目录（如果使用非默认浏览器打开）
        if browserType != nil && browserType != profile.browserType {
            arguments.append("--user-data-dir=\(profile.browserType.dataDirectory)")
        }

        // Profile 目录
        arguments.append("--profile-directory=\(profile.directoryName)")

        // 无痕模式
        if incognito {
            arguments.append("--incognito")
            // 无痕模式需要新窗口
            arguments.append("--new-window")
        }

        // 启动配置参数
        arguments.append(contentsOf: profile.launchConfig.asArguments)

        // 使用 open -a 命令启动，通过 --args 传递参数
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        // 如果 Profile 未运行，使用 -n 开新实例；否则不用 -n
        var openArgs = ["-a", browser.applicationPath]
        if !isRunning || forceNewWindow {
            openArgs.append("-n")
        }
        openArgs.append("--args")
        openArgs.append(contentsOf: arguments)
        process.arguments = openArgs

        do {
            try process.run()
            process.waitUntilExit()
            return .success
        } catch {
            return .launchFailed(error)
        }
    }

    /// 激活已运行的 Profile 窗口
    private func activateExistingProfile(profile: Profile, browser: BrowserType) async -> LaunchResult {
        // 使用 AppleScript 激活浏览器并切换到指定 Profile 的窗口
        let script = """
        tell application "\(browser.displayName)"
            activate
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if error != nil {
            // AppleScript 失败，回退到普通激活
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleIdentifier) {
                _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }

        return .success
    }

    /// 打开浏览器的 Profile 管理页面
    func openProfileManager(for browserType: BrowserType) {
        guard browserType.isInstalled else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: browserType.executablePath)
        process.arguments = ["chrome://settings/manageProfile"]

        try? process.run()
    }

    /// 创建新的 Profile
    func createNewProfile(for browserType: BrowserType, name: String) -> Profile? {
        let dataDir = browserType.dataDirectory

        // 找到下一个可用的 Profile 编号
        var maxNum = 0
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: dataDir) {
            for item in contents {
                if item.hasPrefix("Profile "),
                   let numStr = item.split(separator: " ").last,
                   let num = Int(numStr) {
                    maxNum = max(maxNum, num)
                }
            }
        }

        let newDirName = "Profile \(maxNum + 1)"
        let newPath = "\(dataDir)/\(newDirName)"

        // 创建目录
        do {
            try FileManager.default.createDirectory(
                atPath: newPath,
                withIntermediateDirectories: true
            )

            // 创建基础的 Preferences 文件
            let prefs: [String: Any] = [
                "profile": [
                    "name": name
                ]
            ]
            let prefsData = try JSONSerialization.data(withJSONObject: prefs, options: .prettyPrinted)
            try prefsData.write(to: URL(fileURLWithPath: "\(newPath)/Preferences"))

            return Profile(
                id: "\(browserType.rawValue)_\(newDirName)",
                browserType: browserType,
                directoryName: newDirName,
                originalName: name,
                gaiaName: nil,
                customAlias: nil,
                avatarImagePath: nil,
                avatarIconId: nil,
                lastUsedTime: Date(),
                isFavorite: false,
                launchConfig: .default,
                globalHotkey: nil
            )
        } catch {
            print("Error creating profile: \(error)")
            return nil
        }
    }

    /// 删除 Profile（危险操作，需要确认）
    func deleteProfile(_ profile: Profile) -> Bool {
        let path = profile.fullPath

        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }

        // 检查 Profile 是否正在运行
        if ProfileScanner.shared.isProfileRunning(profile) {
            print("Cannot delete: Profile is currently in use")
            return false
        }

        do {
            // 移动到废纸篓而不是直接删除
            let url = URL(fileURLWithPath: path)
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            print("Error deleting profile: \(error)")
            return false
        }
    }
}
