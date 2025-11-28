import Foundation
import SwiftUI
import Combine

/// 应用全局状态
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    // MARK: - Published Properties

    /// 所有已安装的浏览器
    @Published var browsers: [Browser] = []

    /// 按浏览器分类的 Profile 列表
    @Published var profilesByBrowser: [BrowserType: [Profile]] = [:]

    /// 当前选中的浏览器类型
    @Published var selectedBrowserType: BrowserType = .chrome

    /// 搜索关键词
    @Published var searchText: String = ""

    /// 是否显示主窗口
    @Published var isMainWindowVisible: Bool = false

    /// 正在运行的 Profile ID 列表
    @Published var runningProfileIds: Set<String> = []

    // MARK: - Computed Properties

    /// 当前浏览器的 Profile 列表
    var currentProfiles: [Profile] {
        profilesByBrowser[selectedBrowserType] ?? []
    }

    /// 过滤后的 Profile 列表
    var filteredProfiles: [Profile] {
        let profiles = currentProfiles

        if searchText.isEmpty {
            return profiles
        }

        return profiles.filter { profile in
            profile.displayName.localizedCaseInsensitiveContains(searchText) ||
            profile.directoryName.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 收藏的 Profile 列表（用于菜单栏显示）
    var favoriteProfiles: [Profile] {
        var favorites: [Profile] = []
        for profiles in profilesByBrowser.values {
            favorites.append(contentsOf: profiles.filter { $0.isFavorite })
        }
        return favorites.sorted { $0.displayName < $1.displayName }
    }

    /// 所有 Profile 总数
    var totalProfileCount: Int {
        profilesByBrowser.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Private

    private var runningStateTimer: Timer?

    // MARK: - Init

    private init() {
        loadData()
        startRunningStateMonitor()
    }

    // MARK: - Public Methods

    /// 加载数据
    func loadData() {
        // 获取已安装的浏览器
        browsers = ProfileScanner.shared.getInstalledBrowsers()

        // 扫描所有 Profile
        let userConfigs = ConfigManager.shared.config.profiles
        profilesByBrowser = ProfileScanner.shared.scanAllProfiles(userConfigs: userConfigs)

        // 更新浏览器的 Profile 数量
        browsers = browsers.map { browser in
            let count = profilesByBrowser[browser.type]?.count ?? 0
            return Browser(type: browser.type, profileCount: count)
        }

        // 如果当前选中的浏览器没有安装，切换到第一个已安装的
        if !selectedBrowserType.isInstalled,
           let firstInstalled = browsers.first {
            selectedBrowserType = firstInstalled.type
        }

        // 更新运行状态
        updateRunningState()
    }

    /// 刷新数据
    func refresh() {
        loadData()
    }

    /// 启动 Profile
    func launch(profile: Profile, withBrowser browserType: BrowserType? = nil) {
        Task {
            let result = await BrowserLauncher.shared.launchWithWorkspace(
                profile: profile,
                withBrowser: browserType
            )

            switch result {
            case .success:
                // 延迟一秒后刷新运行状态
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                updateRunningState()
            case .browserNotInstalled:
                print("Browser not installed")
            case .profileNotFound:
                print("Profile not found")
            case .launchFailed(let error):
                print("Launch failed: \(error)")
            }
        }
    }

    /// 以无痕模式启动 Profile
    func launchIncognito(profile: Profile) {
        Task {
            let result = await BrowserLauncher.shared.launchWithWorkspace(
                profile: profile,
                withBrowser: nil,
                incognito: true
            )

            switch result {
            case .success:
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                updateRunningState()
            case .browserNotInstalled:
                print("Browser not installed")
            case .profileNotFound:
                print("Profile not found")
            case .launchFailed(let error):
                print("Launch failed: \(error)")
            }
        }
    }

    /// 切换收藏状态
    func toggleFavorite(profile: Profile) {
        ConfigManager.shared.toggleFavorite(profile: profile)
        loadData()  // 重新加载以更新状态
    }

    /// 更新 Profile 别名
    func setAlias(profile: Profile, alias: String?) {
        ConfigManager.shared.setProfileAlias(profile: profile, alias: alias)
        loadData()
    }

    /// 更新启动配置
    func setLaunchConfig(profile: Profile, config: LaunchConfig) {
        ConfigManager.shared.setLaunchConfig(profile: profile, launchConfig: config)
        loadData()
    }

    /// 创建新 Profile
    func createProfile(name: String) -> Bool {
        guard let _ = BrowserLauncher.shared.createNewProfile(
            for: selectedBrowserType,
            name: name
        ) else {
            return false
        }
        loadData()
        return true
    }

    /// 删除 Profile
    func deleteProfile(_ profile: Profile) -> Bool {
        let success = BrowserLauncher.shared.deleteProfile(profile)
        if success {
            ConfigManager.shared.removeProfileConfig(
                browserType: profile.browserType,
                directoryName: profile.directoryName
            )
            loadData()
        }
        return success
    }

    /// 显示主窗口
    func showMainWindow() {
        isMainWindowVisible = true
    }

    /// 隐藏主窗口
    func hideMainWindow() {
        isMainWindowVisible = false
    }

    // MARK: - Private Methods

    /// 更新运行状态
    private func updateRunningState() {
        var running: Set<String> = []

        for (browserType, profiles) in profilesByBrowser {
            let activeProfiles = ProfileScanner.shared.getActiveProfiles(for: browserType)

            for profile in profiles {
                if activeProfiles.contains(profile.directoryName) &&
                   ProfileScanner.shared.isBrowserRunning(browserType) {
                    running.insert(profile.id)
                }
            }
        }

        runningProfileIds = running
    }

    /// 开始监控运行状态
    private func startRunningStateMonitor() {
        // 每 5 秒更新一次运行状态
        runningStateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRunningState()
            }
        }
    }

    /// 检查 Profile 是否正在运行
    func isProfileRunning(_ profile: Profile) -> Bool {
        runningProfileIds.contains(profile.id)
    }
}
