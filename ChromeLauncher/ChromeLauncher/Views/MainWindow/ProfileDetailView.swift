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
        .onChange(of: profile) { newProfile in
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

    /// 别名编辑（简化版）
    private var aliasSection: some View {
        HStack {
            TextField("自定义别名", text: $editedAlias)
                .textFieldStyle(.roundedBorder)

            Button("保存") {
                let alias = editedAlias.isEmpty ? nil : editedAlias
                appState.setAlias(profile: profile, alias: alias)
            }
            .disabled(editedAlias == (profile.customAlias ?? ""))
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
    @State private var recordedHotkey: String = ""
    @State private var isRecording: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("设置全局快捷键")
                .font(.headline)

            Text("为 \"\(profile.displayName)\" 设置快捷键")
                .foregroundColor(.secondary)

            // 快捷键录制区域
            HotkeyRecorderView(hotkey: $recordedHotkey, isRecording: $isRecording)
                .frame(width: 200, height: 36)

            Text(isRecording ? "请按下快捷键组合..." : "点击上方区域开始录制")
                .font(.caption)
                .foregroundColor(isRecording ? .accentColor : .secondary)

            Text("支持的修饰键: ⌘ Command, ⇧ Shift, ⌃ Control, ⌥ Option")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("清除") {
                    ConfigManager.shared.setProfileHotkey(profile: profile, hotkey: nil)
                    HotkeyManager.shared.unregisterProfileHotkey(profileId: profile.id)
                    dismiss()
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }

                Button("保存") {
                    if !recordedHotkey.isEmpty {
                        ConfigManager.shared.setProfileHotkey(profile: profile, hotkey: recordedHotkey)
                        // 注册新的快捷键
                        _ = HotkeyManager.shared.registerProfileHotkey(profileId: profile.id, keyCombo: recordedHotkey)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(recordedHotkey.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            recordedHotkey = profile.globalHotkey ?? ""
        }
    }
}

/// 快捷键录制视图
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: String
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onHotkeyRecorded = { newHotkey in
            hotkey = newHotkey
            isRecording = false
        }
        view.onRecordingStateChanged = { recording in
            isRecording = recording
        }
        view.currentHotkey = hotkey
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentHotkey = hotkey
    }
}

/// 快捷键录制 NSView
class HotkeyRecorderNSView: NSView {
    var onHotkeyRecorded: ((String) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?
    var currentHotkey: String = "" {
        didSet {
            needsDisplay = true
        }
    }

    private var isRecording = false {
        didSet {
            onRecordingStateChanged?(isRecording)
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 背景
        let bgColor: NSColor = isRecording ? .controlAccentColor.withAlphaComponent(0.1) : .textBackgroundColor
        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        // 边框
        let borderColor: NSColor = isRecording ? .controlAccentColor : .separatorColor
        borderColor.setStroke()
        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        borderPath.lineWidth = 1
        borderPath.stroke()

        // 文字
        let text: String
        let textColor: NSColor
        if isRecording {
            text = "录制中..."
            textColor = .controlAccentColor
        } else if currentHotkey.isEmpty {
            text = "点击录制快捷键"
            textColor = .secondaryLabelColor
        } else {
            text = HotkeyManager.displayString(for: currentHotkey)
            textColor = .labelColor
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = NSRect(x: 0, y: (bounds.height - 20) / 2, width: bounds.width, height: 20)
        text.draw(in: textRect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // ESC 取消录制
        if event.keyCode == 53 {
            isRecording = false
            return
        }

        // 需要至少一个修饰键
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !modifiers.isEmpty else { return }

        // 构建快捷键字符串
        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append("cmd")
        }
        if modifiers.contains(.shift) {
            parts.append("shift")
        }
        if modifiers.contains(.control) {
            parts.append("ctrl")
        }
        if modifiers.contains(.option) {
            parts.append("alt")
        }

        // 获取按键字符
        if let key = keyString(from: event) {
            parts.append(key)
            let hotkeyString = parts.joined(separator: "+")
            currentHotkey = hotkeyString
            onHotkeyRecorded?(hotkeyString)
            isRecording = false
        }
    }

    private func keyString(from event: NSEvent) -> String? {
        // 特殊键处理
        switch event.keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "o"
        case 32: return "u"
        case 33: return "["
        case 34: return "i"
        case 35: return "p"
        case 36: return "return"
        case 37: return "l"
        case 38: return "j"
        case 39: return "'"
        case 40: return "k"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 48: return "tab"
        case 49: return "space"
        case 50: return "`"
        case 51: return "delete"
        case 96: return "f5"
        case 97: return "f6"
        case 98: return "f7"
        case 99: return "f3"
        case 100: return "f8"
        case 101: return "f9"
        case 103: return "f11"
        case 109: return "f10"
        case 111: return "f12"
        case 118: return "f4"
        case 120: return "f2"
        case 122: return "f1"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default:
            // 尝试使用 characters
            if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
                return chars
            }
            return nil
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }
}

#Preview {
    ProfileDetailView(
        profile: Profile(
            id: "test",
            browserType: .chrome,
            directoryName: "Profile 62",
            originalName: "Test Profile",
            gaiaName: "test@gmail.com",
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
