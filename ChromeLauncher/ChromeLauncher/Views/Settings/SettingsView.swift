import SwiftUI

/// 设置视图
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var configManager = ConfigManager.shared

    @State private var globalHotkey: String = ""
    @State private var showInDock: Bool = false
    @State private var launchAtLogin: Bool = false
    @State private var defaultBrowser: BrowserType = .chrome

    @State private var showingExportDialog = false
    @State private var showingImportDialog = false
    @State private var showingResetAlert = false

    var body: some View {
        TabView {
            generalSettingsTab
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            hotkeySettingsTab
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            dataSettingsTab
                .tabItem {
                    Label("数据", systemImage: "externaldrive")
                }

            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Tabs

    /// 通用设置
    private var generalSettingsTab: some View {
        Form {
            Section("显示") {
                Toggle("在 Dock 中显示", isOn: $showInDock)
                    .onChange(of: showInDock) { newValue in
                        var settings = configManager.config.settings
                        settings.showInDock = newValue
                        configManager.updateSettings(settings)

                        // 立即应用
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
            }

            Section("启动") {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        var settings = configManager.config.settings
                        settings.launchAtLogin = newValue
                        configManager.updateSettings(settings)
                        // TODO: 实际注册登录项
                    }
            }

            Section("默认浏览器") {
                Picker("新建 Profile 时默认使用", selection: $defaultBrowser) {
                    ForEach(BrowserType.allCases.filter { $0.isInstalled }) { browserType in
                        Text(browserType.displayName).tag(browserType)
                    }
                }
                .onChange(of: defaultBrowser) { newValue in
                    configManager.setDefaultBrowser(newValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// 快捷键设置
    private var hotkeySettingsTab: some View {
        Form {
            Section("全局快捷键") {
                HStack {
                    Text("打开主界面")
                    Spacer()
                    TextField("cmd+shift+g", text: $globalHotkey)
                        .frame(width: 150)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)

                    Button("保存") {
                        configManager.setGlobalHotkey(globalHotkey)
                        // 重新注册快捷键
                        HotkeyManager.shared.unregisterAllHotkeys()
                        HotkeyManager.shared.registerMainWindowHotkey(globalHotkey)
                    }
                }

                Text("当前: \(HotkeyManager.displayString(for: configManager.config.settings.globalHotkey))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Profile 快捷键") {
                Text("可以在主界面为每个 Profile 单独设置快捷键")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // 显示已设置快捷键的 Profile
                let profilesWithHotkey = getProfilesWithHotkey()
                if profilesWithHotkey.isEmpty {
                    Text("暂无设置快捷键的 Profile")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(profilesWithHotkey, id: \.0) { (profileId, hotkey) in
                        HStack {
                            Text(profileId)
                            Spacer()
                            Text(HotkeyManager.displayString(for: hotkey))
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// 数据设置
    private var dataSettingsTab: some View {
        Form {
            Section("配置文件") {
                HStack {
                    Text("位置")
                    Spacer()
                    Text("~/Library/Application Support/ChromeLauncher/")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("打开") {
                        let path = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Library/Application Support/ChromeLauncher")
                        NSWorkspace.shared.open(path)
                    }
                }
            }

            Section("导入/导出") {
                HStack {
                    Button("导出配置...") {
                        showingExportDialog = true
                    }

                    Button("导入配置...") {
                        showingImportDialog = true
                    }
                }
            }

            Section("重置") {
                Button("重置为默认设置", role: .destructive) {
                    showingResetAlert = true
                }
            }

            Section("统计") {
                LabeledContent("总 Profile 数") {
                    Text("\(appState.totalProfileCount)")
                }
                LabeledContent("收藏数") {
                    Text("\(appState.favoriteProfiles.count)")
                }
                LabeledContent("已安装浏览器") {
                    Text("\(appState.browsers.count)")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileExporter(
            isPresented: $showingExportDialog,
            document: ConfigDocument(config: configManager.config),
            contentType: .json,
            defaultFilename: "ChromeLauncher-config"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingImportDialog,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result {
                do {
                    try configManager.importConfig(from: url)
                    loadSettings()
                    appState.refresh()
                } catch {
                    print("Import failed: \(error)")
                }
            }
        }
        .alert("确认重置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                configManager.resetToDefault()
                loadSettings()
                appState.refresh()
            }
        } message: {
            Text("这将清除所有自定义设置、别名和收藏。此操作不可撤销。")
        }
    }

    /// 关于
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("ChromeLauncher")
                .font(.title)
                .fontWeight(.bold)

            Text("版本 1.0.0")
                .foregroundColor(.secondary)

            Text("Chrome 系浏览器 Profile 启动器")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Text("支持的浏览器:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    ForEach(BrowserType.allCases) { browserType in
                        VStack {
                            if let icon = browserType.appIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .opacity(browserType.isInstalled ? 1.0 : 0.3)
                            }
                            Text(browserType.shortName)
                                .font(.caption2)
                                .foregroundColor(browserType.isInstalled ? .primary : .secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Methods

    private func loadSettings() {
        let settings = configManager.config.settings
        globalHotkey = settings.globalHotkey
        showInDock = settings.showInDock
        launchAtLogin = settings.launchAtLogin
        defaultBrowser = BrowserType(rawValue: settings.defaultBrowser) ?? .chrome
    }

    private func getProfilesWithHotkey() -> [(String, String)] {
        var result: [(String, String)] = []
        for (browserType, profiles) in configManager.config.profiles {
            for (dirName, config) in profiles {
                if let hotkey = config.globalHotkey {
                    let displayName = config.alias ?? dirName
                    result.append(("\(displayName) (\(browserType))", hotkey))
                }
            }
        }
        return result
    }
}

/// 配置文件文档（用于导出）
struct ConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    init(configuration: ReadConfiguration) throws {
        let decoder = JSONDecoder()
        config = try decoder.decode(AppConfig.self, from: configuration.file.regularFileContents ?? Data())
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        return FileWrapper(regularFileWithContents: data)
    }
}

import UniformTypeIdentifiers

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
