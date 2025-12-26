import Foundation
import AppKit

/// 支持的浏览器类型
enum BrowserType: String, CaseIterable, Codable, Identifiable {
    case chrome = "chrome"
    case chromeCanary = "chrome_canary"
    case chromium = "chromium"
    case edge = "edge"
    case brave = "brave"
    case vivaldi = "vivaldi"
    case helium = "helium"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .chromeCanary: return "Chrome Canary"
        case .chromium: return "Ungoogled"
        case .edge: return "Microsoft Edge"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        case .helium: return "Helium"
        }
    }

    var shortName: String {
        switch self {
        case .chrome: return "Chrome"
        case .chromeCanary: return "Canary"
        case .chromium: return "Ungoogled"
        case .edge: return "Edge"
        case .brave: return "Brave"
        case .vivaldi: return "Vivaldi"
        case .helium: return "Helium"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .chromeCanary: return "com.google.Chrome.canary"
        case .chromium: return "org.chromium.Chromium"
        case .edge: return "com.microsoft.edgemac"
        case .brave: return "com.brave.Browser"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .helium: return "net.imput.helium"
        }
    }

    var applicationPath: String {
        switch self {
        case .chrome: return "/Applications/Google Chrome.app"
        case .chromeCanary: return "/Applications/Google Chrome Canary.app"
        case .chromium: return "/Applications/Chromium.app"
        case .edge: return "/Applications/Microsoft Edge.app"
        case .brave: return "/Applications/Brave Browser.app"
        case .vivaldi: return "/Applications/Vivaldi.app"
        case .helium: return "/Applications/Helium.app"
        }
    }

    var executablePath: String {
        switch self {
        case .chrome: return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        case .chromeCanary: return "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
        case .chromium: return "/Applications/Chromium.app/Contents/MacOS/Chromium"
        case .edge: return "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
        case .brave: return "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
        case .vivaldi: return "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi"
        case .helium: return "/Applications/Helium.app/Contents/MacOS/Helium"
        }
    }

    var dataDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .chrome: return "\(home)/Library/Application Support/Google/Chrome"
        case .chromeCanary: return "\(home)/Library/Application Support/Google/Chrome Canary"
        case .chromium: return "\(home)/Library/Application Support/Chromium"
        case .edge: return "\(home)/Library/Application Support/Microsoft Edge"
        case .brave: return "\(home)/Library/Application Support/BraveSoftware/Brave-Browser"
        case .vivaldi: return "\(home)/Library/Application Support/Vivaldi"
        case .helium: return "\(home)/Library/Application Support/net.imput.helium"
        }
    }

    var iconName: String {
        switch self {
        case .chrome: return "chrome"
        case .chromeCanary: return "chrome_canary"
        case .chromium: return "chromium"
        case .edge: return "edge"
        case .brave: return "brave"
        case .vivaldi: return "vivaldi"
        case .helium: return "helium"
        }
    }

    /// 获取浏览器应用图标
    var appIcon: NSImage? {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return workspace.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "globe", accessibilityDescription: displayName)
    }

    /// 检查浏览器是否已安装
    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: applicationPath)
    }

    /// 检查是否有数据目录
    var hasDataDirectory: Bool {
        FileManager.default.fileExists(atPath: dataDirectory)
    }
}

/// 浏览器实例（包含安装状态等运行时信息）
struct Browser: Identifiable {
    let type: BrowserType
    let isInstalled: Bool
    let hasData: Bool
    let profileCount: Int

    var id: String { type.rawValue }

    init(type: BrowserType) {
        self.type = type
        self.isInstalled = type.isInstalled
        self.hasData = type.hasDataDirectory
        self.profileCount = 0  // 将由 ProfileScanner 填充
    }

    init(type: BrowserType, profileCount: Int) {
        self.type = type
        self.isInstalled = type.isInstalled
        self.hasData = type.hasDataDirectory
        self.profileCount = profileCount
    }
}
