import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotkeyManager = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 应用（不显示在 Dock）
        if !ConfigManager.shared.config.settings.showInDock {
            NSApp.setActivationPolicy(.accessory)
        }

        // 注册全局快捷键
        setupHotkeys()

        // 设置快捷键回调
        hotkeyManager.onShowMainWindow = { [weak self] in
            self?.showMainWindow()
        }

        hotkeyManager.onProfileHotkey = { profileId in
            Task { @MainActor in
                self.launchProfileById(profileId)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 清理快捷键
        hotkeyManager.unregisterAllHotkeys()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    // MARK: - Private Methods

    private func setupHotkeys() {
        // 注册主窗口快捷键
        let globalHotkey = ConfigManager.shared.config.settings.globalHotkey
        hotkeyManager.registerMainWindowHotkey(globalHotkey)

        // 注册 Profile 快捷键
        for (browserType, profiles) in ConfigManager.shared.config.profiles {
            for (dirName, config) in profiles {
                if let hotkey = config.globalHotkey {
                    let profileId = "\(browserType)_\(dirName)"
                    hotkeyManager.registerProfileHotkey(profileId: profileId, keyCombo: hotkey)
                }
            }
        }
    }

    @MainActor
    private func showMainWindow() {
        AppState.shared.showMainWindow()

        // 激活应用并显示窗口
        NSApp.activate(ignoringOtherApps: true)

        // 打开主窗口
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // 如果窗口不存在，通过 openWindow 打开
            if #available(macOS 13.0, *) {
                NSApp.sendAction(Selector(("showMainWindow:")), to: nil, from: nil)
            }
        }
    }

    @MainActor
    private func launchProfileById(_ profileId: String) {
        // 在所有 Profile 中查找
        for profiles in AppState.shared.profilesByBrowser.values {
            if let profile = profiles.first(where: { $0.id == profileId }) {
                AppState.shared.launch(profile: profile)
                return
            }
        }
    }
}
