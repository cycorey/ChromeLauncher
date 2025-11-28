import Foundation

/// 应用配置（存储在 config.json）
struct AppConfig: Codable {
    var version: String = "1.0"
    var settings: AppSettings
    var profiles: [String: [String: ProfileUserConfig]]  // browserType -> directoryName -> config

    static let `default` = AppConfig(
        version: "1.0",
        settings: .default,
        profiles: [:]
    )
}

/// 应用设置
struct AppSettings: Codable {
    var globalHotkey: String
    var showInDock: Bool
    var launchAtLogin: Bool
    var defaultBrowser: String  // BrowserType.rawValue

    static let `default` = AppSettings(
        globalHotkey: "alt+g",
        showInDock: false,
        launchAtLogin: false,
        defaultBrowser: BrowserType.chrome.rawValue
    )
}

/// 收藏的快捷启动项
struct FavoriteItem: Codable, Identifiable {
    let id: String  // Profile 的 id
    let browserType: String
    let profileDirectory: String
    var sortOrder: Int

    init(profile: Profile, sortOrder: Int = 0) {
        self.id = profile.id
        self.browserType = profile.browserType.rawValue
        self.profileDirectory = profile.directoryName
        self.sortOrder = sortOrder
    }
}
