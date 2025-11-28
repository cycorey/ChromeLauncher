import Foundation
import Carbon
import AppKit

/// 全局快捷键管理服务
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private var hotkeys: [UInt32: () -> Void] = [:]
    private var hotkeyRefs: [UInt32: EventHotKeyRef?] = [:]
    private var nextHotkeyId: UInt32 = 1

    /// 主窗口显示回调
    var onShowMainWindow: (() -> Void)?

    /// Profile 快捷键回调
    var onProfileHotkey: ((String) -> Void)?  // profileId

    private init() {
        setupEventHandler()
    }

    /// 设置事件处理器
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotkeyId = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyId
                )

                HotkeyManager.shared.handleHotkey(id: hotkeyId.id)
                return noErr
            },
            1,
            &eventSpec,
            nil,
            nil
        )
    }

    /// 处理快捷键事件
    private func handleHotkey(id: UInt32) {
        if let action = hotkeys[id] {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    /// 注册全局快捷键
    @discardableResult
    func registerHotkey(keyCombo: String, action: @escaping () -> Void) -> UInt32? {
        guard let (keyCode, modifiers) = parseKeyCombo(keyCombo) else {
            print("Invalid key combo: \(keyCombo)")
            return nil
        }

        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4348), id: hotkeyId)  // "CLCH"
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotkeys[hotkeyId] = action
            hotkeyRefs[hotkeyId] = hotKeyRef
            return hotkeyId
        } else {
            print("Failed to register hotkey: \(status)")
            return nil
        }
    }

    /// 注销快捷键
    func unregisterHotkey(id: UInt32) {
        if let ref = hotkeyRefs[id], let hotKeyRef = ref {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotkeys.removeValue(forKey: id)
        hotkeyRefs.removeValue(forKey: id)
    }

    /// 注销所有快捷键
    func unregisterAllHotkeys() {
        for (id, _) in hotkeys {
            unregisterHotkey(id: id)
        }
    }

    /// 解析快捷键字符串
    /// 格式: "cmd+shift+g", "ctrl+alt+1"
    private func parseKeyCombo(_ combo: String) -> (keyCode: Int, modifiers: Int)? {
        let parts = combo.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var modifiers: Int = 0
        var keyCode: Int?

        for part in parts {
            switch part {
            case "cmd", "command", "⌘":
                modifiers |= cmdKey
            case "shift", "⇧":
                modifiers |= shiftKey
            case "ctrl", "control", "⌃":
                modifiers |= controlKey
            case "alt", "option", "⌥":
                modifiers |= optionKey
            default:
                // 最后一个部分应该是键名
                keyCode = keyCodeFor(part)
            }
        }

        guard let code = keyCode else {
            return nil
        }

        return (code, modifiers)
    }

    /// 获取键码
    private func keyCodeFor(_ key: String) -> Int? {
        let keyMap: [String: Int] = [
            // 字母
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,

            // 数字
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,

            // 功能键
            "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
            "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
            "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,

            // 特殊键
            "space": kVK_Space,
            "return": kVK_Return, "enter": kVK_Return,
            "tab": kVK_Tab,
            "escape": kVK_Escape, "esc": kVK_Escape,
            "delete": kVK_Delete,
            "backspace": kVK_Delete,

            // 方向键
            "up": kVK_UpArrow, "down": kVK_DownArrow,
            "left": kVK_LeftArrow, "right": kVK_RightArrow,

            // 符号
            "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
            "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
            ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
            ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period,
            "/": kVK_ANSI_Slash, "\\": kVK_ANSI_Backslash,
            "`": kVK_ANSI_Grave
        ]

        return keyMap[key]
    }

    // MARK: - 便捷方法

    /// 注册主窗口快捷键
    func registerMainWindowHotkey(_ keyCombo: String) {
        registerHotkey(keyCombo: keyCombo) { [weak self] in
            self?.onShowMainWindow?()
        }
    }

    /// 注册 Profile 快捷键
    func registerProfileHotkey(profileId: String, keyCombo: String) -> UInt32? {
        registerHotkey(keyCombo: keyCombo) { [weak self] in
            self?.onProfileHotkey?(profileId)
        }
    }

    /// 将快捷键字符串转换为显示格式
    static func displayString(for keyCombo: String) -> String {
        let parts = keyCombo.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        var display: [String] = []

        for part in parts {
            switch part {
            case "cmd", "command": display.append("⌘")
            case "shift": display.append("⇧")
            case "ctrl", "control": display.append("⌃")
            case "alt", "option": display.append("⌥")
            default: display.append(part.uppercased())
            }
        }

        return display.joined()
    }
}
