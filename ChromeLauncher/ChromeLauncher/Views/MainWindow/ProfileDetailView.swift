import SwiftUI

/// Profile 详情视图
struct ProfileDetailView: View {
    let profile: Profile

    @EnvironmentObject var appState: AppState
    @State private var editedAlias: String = ""
    @State private var launchConfig: LaunchConfig = .default
    @State private var customArgsText: String = ""
    @State private var showingHotkeySheet = false
    @State private var showingBrowserWarning = false
    @State private var selectedOtherBrowser: BrowserType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 头部信息
                headerSection

                Divider()

                // 别名编辑
                aliasSection

                Divider()

                // 启动选项
                launchOptionsSection

                Divider()

                // 快捷键设置
                hotkeySection

                Divider()

                // 操作按钮
                actionSection

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadProfileData()
        }
        .onChange(of: profile) { _, newProfile in
            loadProfileData()
        }
        .sheet(isPresented: $showingHotkeySheet) {
            HotkeySettingSheet(profile: profile)
        }
        .alert("跨浏览器打开警告", isPresented: $showingBrowserWarning) {
            Button("取消", role: .cancel) {}
            Button("继续打开") {
                if let browser = selectedOtherBrowser {
                    appState.launch(profile: profile, withBrowser: browser)
                }
            }
        } message: {
            Text("使用其他浏览器打开可能会导致数据不兼容或丢失。建议仅在测试时使用此功能。")
        }
    }

    // MARK: - Sections

    /// 头部信息
    private var headerSection: some View {
        HStack(spacing: 16) {
            ProfileAvatarView(profile: profile, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if appState.isProfileRunning(profile) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("运行中")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                HStack(spacing: 12) {
                    Label(profile.directoryName, systemImage: "folder")
                    Label(profile.browserType.shortName, systemImage: "globe")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let lastUsed = profile.lastUsedTime {
                    Text("最后使用: \(lastUsed.relativeString)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 收藏按钮
            Button {
                appState.toggleFavorite(profile: profile)
            } label: {
                Image(systemName: profile.isFavorite ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundColor(profile.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(profile.isFavorite ? "取消收藏" : "添加到收藏")
        }
    }

    /// 别名编辑
    private var aliasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自定义别名")
                .font(.headline)

            HStack {
                TextField("输入别名（留空使用原名）", text: $editedAlias)
                    .textFieldStyle(.roundedBorder)

                Button("保存") {
                    let alias = editedAlias.isEmpty ? nil : editedAlias
                    appState.setAlias(profile: profile, alias: alias)
                }
                .disabled(editedAlias == (profile.customAlias ?? ""))
            }

            Text("原名称: \(profile.originalName)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 启动选项
    private var launchOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("启动选项")
                .font(.headline)

            // 常用选项
            VStack(alignment: .leading, spacing: 8) {
                Toggle("无痕模式 (--incognito)", isOn: $launchConfig.incognito)
                Toggle("禁用扩展 (--disable-extensions)", isOn: $launchConfig.disableExtensions)
                Toggle("新窗口 (--new-window)", isOn: $launchConfig.newWindow)
                Toggle("全屏启动 (--start-fullscreen)", isOn: $launchConfig.startFullscreen)
            }

            // 窗口大小
            HStack {
                Toggle("指定窗口大小", isOn: Binding(
                    get: { launchConfig.windowSize != nil },
                    set: { enabled in
                        launchConfig.windowSize = enabled ? LaunchConfig.WindowSize(width: 1920, height: 1080) : nil
                    }
                ))

                if launchConfig.windowSize != nil {
                    TextField("宽度", value: Binding(
                        get: { launchConfig.windowSize?.width ?? 1920 },
                        set: { launchConfig.windowSize?.width = $0 }
                    ), format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)

                    Text("×")

                    TextField("高度", value: Binding(
                        get: { launchConfig.windowSize?.height ?? 1080 },
                        set: { launchConfig.windowSize?.height = $0 }
                    ), format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                }
            }

            // 自定义参数
            VStack(alignment: .leading, spacing: 4) {
                Text("自定义参数（每行一个）")
                    .font(.subheadline)

                TextEditor(text: $customArgsText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))
            }

            // 保存按钮
            HStack {
                Spacer()
                Button("保存启动配置") {
                    savelaunchConfig()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// 快捷键设置
    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("全局快捷键")
                .font(.headline)

            HStack {
                if let hotkey = profile.globalHotkey {
                    Text(HotkeyManager.displayString(for: hotkey))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("未设置")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("设置快捷键") {
                    showingHotkeySheet = true
                }
            }

            Text("设置后可通过快捷键快速启动此 Profile")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 操作按钮
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作")
                .font(.headline)

            HStack(spacing: 12) {
                // 主启动按钮
                Button {
                    appState.launch(profile: profile)
                } label: {
                    Label("启动", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // 无痕模式启动
                Button {
                    var tempProfile = profile
                    tempProfile.launchConfig.incognito = true
                    appState.launch(profile: tempProfile)
                } label: {
                    Label("无痕启动", systemImage: "eye.slash")
                }
                .controlSize(.large)
            }

            // 用其他浏览器打开
            if BrowserType.allCases.filter({ $0.isInstalled && $0 != profile.browserType }).count > 0 {
                Divider()

                Text("用其他浏览器打开")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(BrowserType.allCases.filter({ $0.isInstalled && $0 != profile.browserType })) { browserType in
                        Button {
                            selectedOtherBrowser = browserType
                            showingBrowserWarning = true
                        } label: {
                            if let icon = browserType.appIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("用 \(browserType.displayName) 打开")
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func loadProfileData() {
        editedAlias = profile.customAlias ?? ""
        launchConfig = profile.launchConfig
        customArgsText = launchConfig.customArgs.joined(separator: "\n")
    }

    private func savelaunchConfig() {
        // 解析自定义参数
        launchConfig.customArgs = customArgsText
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        appState.setLaunchConfig(profile: profile, config: launchConfig)
    }
}

/// 快捷键设置 Sheet
struct HotkeySettingSheet: View {
    let profile: Profile
    @Environment(\.dismiss) var dismiss
    @State private var hotkeyText: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("设置全局快捷键")
                .font(.headline)

            Text("为 \"\(profile.displayName)\" 设置快捷键")
                .foregroundColor(.secondary)

            TextField("例如: cmd+shift+1", text: $hotkeyText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Text("支持的修饰键: cmd, shift, ctrl, alt")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("清除") {
                    ConfigManager.shared.setProfileHotkey(profile: profile, hotkey: nil)
                    dismiss()
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }

                Button("保存") {
                    if !hotkeyText.isEmpty {
                        ConfigManager.shared.setProfileHotkey(profile: profile, hotkey: hotkeyText)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hotkeyText.isEmpty)
            }
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            hotkeyText = profile.globalHotkey ?? ""
        }
    }
}

#Preview {
    ProfileDetailView(
        profile: Profile(
            id: "test",
            browserType: .chrome,
            directoryName: "Profile 62",
            originalName: "Test Profile",
            customAlias: "工作账号",
            avatarImagePath: nil,
            avatarIconId: nil,
            lastUsedTime: Date(),
            isFavorite: true,
            launchConfig: .default,
            globalHotkey: "cmd+shift+1"
        )
    )
    .environmentObject(AppState.shared)
    .frame(width: 400, height: 600)
}
