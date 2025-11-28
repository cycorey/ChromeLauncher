import SwiftUI

@main
struct ChromeLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // 主窗口
        Window("ChromeLauncher", id: "main") {
            MainWindowView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 600)

        // 设置窗口
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        // 菜单栏
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "globe")
        }
        .menuBarExtraStyle(.menu)
    }
}
