import Foundation

/// 配置管理服务
class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let configDirectoryPath: String
    private let configFilePath: String

    @Published var config: AppConfig

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        configDirectoryPath = "\(home)/Library/Application Support/ChromeLauncher"
        configFilePath = "\(configDirectoryPath)/config.json"

        // 加载配置
        config = Self.loadConfig(from: configFilePath) ?? .default

        // 确保配置目录存在
        createConfigDirectoryIfNeeded()
    }

    /// 创建配置目录
    private func createConfigDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: configDirectoryPath) {
            try? FileManager.default.createDirectory(
                atPath: configDirectoryPath,
                withIntermediateDirectories: true
            )
        }
    }

    /// 加载配置
    private static func loadConfig(from path: String) -> AppConfig? {
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("Error loading config: \(error)")
            return nil
        }
    }

    /// 保存配置
    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: URL(fileURLWithPath: configFilePath))
        } catch {
            print("Error saving config: \(error)")
        }
    }

    // MARK: - Profile 配置操作

    /// 获取 Profile 用户配置
    func getProfileConfig(browserType: BrowserType, directoryName: String) -> ProfileUserConfig? {
        config.profiles[browserType.rawValue]?[directoryName]
    }

    /// 更新 Profile 用户配置
    func updateProfileConfig(
        browserType: BrowserType,
        directoryName: String,
        config newConfig: ProfileUserConfig
    ) {
        if config.profiles[browserType.rawValue] == nil {
            config.profiles[browserType.rawValue] = [:]
        }
        config.profiles[browserType.rawValue]?[directoryName] = newConfig
        saveConfig()
    }

    /// 更新 Profile 别名
    func setProfileAlias(profile: Profile, alias: String?) {
        var profileConfig = getProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName
        ) ?? .default

        profileConfig.alias = alias
        updateProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName,
            config: profileConfig
        )
    }

    /// 切换收藏状态
    func toggleFavorite(profile: Profile) {
        var profileConfig = getProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName
        ) ?? .default

        profileConfig.isFavorite.toggle()
        updateProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName,
            config: profileConfig
        )
    }

    /// 设置启动配置
    func setLaunchConfig(profile: Profile, launchConfig: LaunchConfig) {
        var profileConfig = getProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName
        ) ?? .default

        profileConfig.launchConfig = launchConfig
        updateProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName,
            config: profileConfig
        )
    }

    /// 设置全局快捷键
    func setProfileHotkey(profile: Profile, hotkey: String?) {
        var profileConfig = getProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName
        ) ?? .default

        profileConfig.globalHotkey = hotkey
        updateProfileConfig(
            browserType: profile.browserType,
            directoryName: profile.directoryName,
            config: profileConfig
        )
    }

    // MARK: - 收藏列表

    /// 获取所有收藏的 Profile ID
    func getFavoriteProfileIds() -> [String] {
        var favorites: [String] = []
        for (browserType, profiles) in config.profiles {
            for (dirName, profileConfig) in profiles {
                if profileConfig.isFavorite {
                    favorites.append("\(browserType)_\(dirName)")
                }
            }
        }
        return favorites
    }

    // MARK: - 设置操作

    /// 更新应用设置
    func updateSettings(_ settings: AppSettings) {
        config.settings = settings
        saveConfig()
    }

    /// 设置全局快捷键
    func setGlobalHotkey(_ hotkey: String) {
        config.settings.globalHotkey = hotkey
        saveConfig()
    }

    /// 设置默认浏览器
    func setDefaultBrowser(_ browserType: BrowserType) {
        config.settings.defaultBrowser = browserType.rawValue
        saveConfig()
    }

    /// 获取快速过滤按钮配置
    func getQuickFilters() -> [QuickFilter] {
        // 确保始终有9个过滤器
        var filters = config.settings.quickFilters
        if filters.count < 9 {
            let existing = Set(filters.map { $0.id })
            for i in 1...9 where !existing.contains(i) {
                filters.append(QuickFilter(id: i, text: "", isEnabled: false))
            }
            filters.sort { $0.id < $1.id }
        }
        return filters
    }

    /// 更新快速过滤按钮配置
    func setQuickFilter(id: Int, text: String) {
        var filters = getQuickFilters()
        if let index = filters.firstIndex(where: { $0.id == id }) {
            filters[index].text = text
            filters[index].isEnabled = !text.isEmpty
        }
        config.settings.quickFilters = filters
        saveConfig()
    }

    /// 批量更新快速过滤按钮配置
    func setQuickFilters(_ filters: [QuickFilter]) {
        config.settings.quickFilters = filters
        saveConfig()
    }

    // MARK: - 导入/导出

    /// 导出配置
    func exportConfig(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    /// 导入配置
    func importConfig(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let importedConfig = try decoder.decode(AppConfig.self, from: data)
        config = importedConfig
        saveConfig()
    }

    /// 重置为默认配置
    func resetToDefault() {
        config = .default
        saveConfig()
    }

    // MARK: - Profile 删除后的清理

    /// 删除 Profile 相关配置
    func removeProfileConfig(browserType: BrowserType, directoryName: String) {
        config.profiles[browserType.rawValue]?[directoryName] = nil
        saveConfig()
    }
}
