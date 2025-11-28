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

        // 如果已经运行且不是强制新窗口或无痕模式，直接激活浏览器窗口
        if isRunning && !forceNewWindow && !incognito {
            return activateBrowserWindow(browser: browser, profile: profile)
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

        // 使用 open -n 启动新实例
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", browser.applicationPath, "--args"] + arguments

        do {
            try process.run()
            process.waitUntilExit()
            return .success
        } catch {
            return .launchFailed(error)
        }
    }

    /// 激活已运行的浏览器窗口
    private func activateBrowserWindow(browser: BrowserType, profile: Profile) -> LaunchResult {
        // 策略：
        // 1. 调用 Chrome 可执行文件 + --profile-directory + URL
        //    触发 Chrome 内部 profile 激活逻辑
        // 2. 用 AppleScript activate 将整个应用带到前台
        // 3. 延迟后发送 ⌘W 关闭标签页

        // 第一步：调用 Chrome 可执行文件
        let process = Process()
        process.executableURL = URL(fileURLWithPath: browser.executablePath)
        process.arguments = ["--profile-directory=\(profile.directoryName)", "https://ifconfig.co"]

        do {
            try process.run()
        } catch {
            // 如果失败，继续尝试 AppleScript
        }

        // 第二步：使用 AppleScript 激活应用
        let activateScript = """
        tell application "\(browser.displayName)"
            activate
        end tell
        """

        let appleScript = NSAppleScript(source: activateScript)
        var appleError: NSDictionary?
        appleScript?.executeAndReturnError(&appleError)

        // 第三步：延迟后关闭当前标签页（使用 osascript 命令行工具）
        let browserName = browser.displayName
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            let closeProcess = Process()
            closeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            closeProcess.arguments = [
                "-e",
                "tell application \"\(browserName)\" to tell front window to close active tab"
            ]
            try? closeProcess.run()
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

    /// 启动新创建的 Profile（用于初始化）
    func launchNewProfile(
        profile: Profile,
        windowSize: LaunchConfig.WindowSize? = nil
    ) async -> LaunchResult {
        let browser = profile.browserType

        guard browser.isInstalled else {
            return .browserNotInstalled
        }

        // 构建参数
        var arguments: [String] = []

        // Profile 目录
        arguments.append("--profile-directory=\(profile.directoryName)")

        // 窗口大小 - 新建 Profile 时使用较大的窗口确保内容显示完整
        if let size = windowSize {
            arguments.append("--window-size=\(size.asArgument)")
        }

        // 新窗口
        arguments.append("--new-window")

        // 打开 Profile 设置页面
        arguments.append("chrome://settings/manageProfile")

        // 直接使用 Chrome 可执行文件启动，确保窗口大小参数生效
        let process = Process()
        process.executableURL = URL(fileURLWithPath: browser.executablePath)
        process.arguments = arguments

        do {
            try process.run()
            return .success
        } catch {
            return .launchFailed(error)
        }
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
