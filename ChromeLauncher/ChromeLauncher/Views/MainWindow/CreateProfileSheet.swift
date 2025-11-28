import SwiftUI

/// 创建 Profile Sheet
struct CreateProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var profileName: String = ""
    @State private var selectedBrowser: BrowserType = .chrome
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("创建新 Profile")
                .font(.title2)
                .fontWeight(.semibold)

            // 浏览器选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择浏览器")
                    .font(.headline)

                Picker("浏览器", selection: $selectedBrowser) {
                    ForEach(BrowserType.allCases.filter { $0.isInstalled }) { browserType in
                        HStack {
                            if let icon = browserType.appIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(browserType.displayName)
                        }
                        .tag(browserType)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Profile 名称
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile 名称")
                    .font(.headline)

                TextField("输入名称", text: $profileName)
                    .textFieldStyle(.roundedBorder)

                Text("这个名称将显示在浏览器的 Profile 选择器中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // 按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("创建") {
                    createProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileName.isEmpty || isCreating)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 800, height: 300)
        .onAppear {
            selectedBrowser = appState.selectedBrowserType
        }
    }

    private func createProfile() {
        isCreating = true
        errorMessage = nil

        // 验证名称
        guard !profileName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Profile 名称不能为空"
            isCreating = false
            return
        }

        // 创建 Profile
        if let profile = BrowserLauncher.shared.createNewProfile(
            for: selectedBrowser,
            name: profileName.trimmingCharacters(in: .whitespaces)
        ) {
            // 启动浏览器来初始化 Profile，使用合理的窗口大小
            Task {
                // 使用 1280x800 作为默认窗口大小，确保内容显示完整
                let _ = await BrowserLauncher.shared.launchNewProfile(
                    profile: profile,
                    windowSize: LaunchConfig.WindowSize(width: 1280, height: 800)
                )
            }
            appState.refresh()
            dismiss()
        } else {
            errorMessage = "创建失败，请检查权限或稍后重试"
            isCreating = false
        }
    }
}

#Preview {
    CreateProfileSheet()
        .environmentObject(AppState.shared)
}
