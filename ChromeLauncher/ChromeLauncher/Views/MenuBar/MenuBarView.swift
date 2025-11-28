import SwiftUI

/// 菜单栏下拉视图
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // 收藏的快捷启动项
        if !appState.favoriteProfiles.isEmpty {
            ForEach(appState.favoriteProfiles) { profile in
                Button {
                    appState.launch(profile: profile)
                } label: {
                    HStack {
                        // 浏览器图标
                        if let icon = profile.browserType.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }

                        Text(profile.displayName)

                        Spacer()

                        // 运行状态指示
                        if appState.isProfileRunning(profile) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                        }

                        // 浏览器类型标签
                        Text(profile.browserType.shortName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()
        }

        // 打开完整界面
        Button {
            openMainWindow()
        } label: {
            HStack {
                Image(systemName: "rectangle.grid.2x2")
                Text("打开完整界面")
                Spacer()
                Text("⌘⇧G")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .keyboardShortcut("g", modifiers: [.command, .shift])

        Divider()

        // 快速启动子菜单（按浏览器分组）
        Menu("快速启动") {
            ForEach(BrowserType.allCases.filter { $0.isInstalled }) { browserType in
                if let profiles = appState.profilesByBrowser[browserType], !profiles.isEmpty {
                    Menu(browserType.displayName) {
                        ForEach(profiles.prefix(10)) { profile in
                            Button {
                                appState.launch(profile: profile)
                            } label: {
                                HStack {
                                    Text(profile.displayName)
                                    if appState.isProfileRunning(profile) {
                                        Spacer()
                                        Image(systemName: "circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                    }
                                }
                            }
                        }

                        if profiles.count > 10 {
                            Divider()
                            Text("还有 \(profiles.count - 10) 个 Profile...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }

        Divider()

        // 刷新
        Button {
            appState.refresh()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("刷新 Profile 列表")
            }
        }

        // 设置
        Button {
            openSettings()
        } label: {
            HStack {
                Image(systemName: "gear")
                Text("设置...")
            }
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // 退出
        Button {
            NSApp.terminate(nil)
        } label: {
            Text("退出 ChromeLauncher")
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func openMainWindow() {
        appState.showMainWindow()
        NSApp.activate(ignoringOtherApps: true)

        // 使用 Environment 打开窗口
        if let window = NSApp.windows.first(where: { $0.title == "ChromeLauncher" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // 打开设置窗口
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState.shared)
}
