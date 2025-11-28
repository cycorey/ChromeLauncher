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

/// 快速过滤按钮配置
struct QuickFilter: Codable, Identifiable, Equatable {
    var id: Int  // 1-9 对应 ⌘1-9
    var text: String  // 过滤文本
    var isEnabled: Bool  // 是否启用

    static func defaultFilters() -> [QuickFilter] {
        (1...9).map { QuickFilter(id: $0, text: "", isEnabled: false) }
    }
}

/// 应用设置
struct AppSettings: Codable {
    var globalHotkey: String
    var showInDock: Bool
    var launchAtLogin: Bool
    var defaultBrowser: String  // BrowserType.rawValue
    var quickFilters: [QuickFilter]  // 快速过滤按钮配置

    static let `default` = AppSettings(
        globalHotkey: "alt+g",
        showInDock: false,
        launchAtLogin: false,
        defaultBrowser: BrowserType.chrome.rawValue,
        quickFilters: QuickFilter.defaultFilters()
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
