import Foundation
import AppKit

/// Chrome Profile 模型
struct Profile: Identifiable, Hashable {
    let id: String  // 唯一标识: browserType_profileDirectory
    let browserType: BrowserType
    let directoryName: String  // e.g., "Profile 62", "Default"
    let originalName: String   // 从浏览器读取的原始名称 (name 字段)
    let gaiaName: String?      // Google 账号名称 (gaia_name 字段)
    var customAlias: String?   // 用户自定义别名
    let avatarImagePath: String?  // Google 账号头像路径
    let avatarIconId: String?     // Chrome 内置头像 ID
    let lastUsedTime: Date?
    var isFavorite: Bool
    var launchConfig: LaunchConfig
    var globalHotkey: String?

    /// 显示名称（优先使用别名）
    var displayName: String {
        if let alias = customAlias {
            return alias
        }
        // 格式: 自定义名称 (Google账号名)
        if let gaia = gaiaName, !gaia.isEmpty {
            return "\(originalName) (\(gaia))"
        }
        return originalName
    }

    /// 完整的 Profile 目录路径
    var fullPath: String {
        "\(browserType.dataDirectory)/\(directoryName)"
    }

    /// 获取头像图片
    var avatarImage: NSImage? {
        // 优先使用 Google 账号头像
        if let imagePath = avatarImagePath,
           FileManager.default.fileExists(atPath: imagePath) {
            return NSImage(contentsOfFile: imagePath)
        }
        // 回退到默认图标
        return NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: displayName)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }
}

/// 启动配置
struct LaunchConfig: Codable, Hashable {
    var incognito: Bool = false
    var windowSize: WindowSize?
    var disableExtensions: Bool = false
    var newWindow: Bool = false
    var startFullscreen: Bool = false
    var customArgs: [String] = []

    /// 窗口大小配置
    struct WindowSize: Codable, Hashable {
        var width: Int
        var height: Int

        var asArgument: String {
            "\(width),\(height)"
        }
    }

    /// 转换为命令行参数
    var asArguments: [String] {
        var args: [String] = []

        if incognito {
            args.append("--incognito")
        }
        if let size = windowSize {
            args.append("--window-size=\(size.asArgument)")
        }
        if disableExtensions {
            args.append("--disable-extensions")
        }
        if newWindow {
            args.append("--new-window")
        }
        if startFullscreen {
            args.append("--start-fullscreen")
        }
        args.append(contentsOf: customArgs)

        return args
    }

    /// 预设配置
    static let `default` = LaunchConfig()

    static let incognitoMode = LaunchConfig(incognito: true)

    static let fullHD = LaunchConfig(windowSize: WindowSize(width: 1920, height: 1080))

    static let noExtensions = LaunchConfig(disableExtensions: true)
}

/// Profile 运行状态
enum ProfileRunningState {
    case notRunning
    case running
    case unknown
}

/// 扩展：从 Local State JSON 解析 Profile 信息
extension Profile {
    /// 从 Local State 的 info_cache 创建 Profile
    static func from(
        browserType: BrowserType,
        directoryName: String,
        infoCache: [String: Any],
        userConfig: ProfileUserConfig?
    ) -> Profile {
        // Local State 中的 name 字段就是用户在 Chrome 中设置的自定义名称
        let name = infoCache["name"] as? String ?? directoryName
        let gaiaName = infoCache["gaia_name"] as? String
        let avatarIcon = infoCache["avatar_icon"] as? String

        // 头像路径
        let avatarPath = "\(browserType.dataDirectory)/\(directoryName)/Google Profile Picture.png"
        let hasAvatar = FileManager.default.fileExists(atPath: avatarPath)

        // 最后使用时间（从目录修改时间获取）
        let dirPath = "\(browserType.dataDirectory)/\(directoryName)"
        let lastUsed: Date? = {
            let attrs = try? FileManager.default.attributesOfItem(atPath: dirPath)
            return attrs?[.modificationDate] as? Date
        }()

        return Profile(
            id: "\(browserType.rawValue)_\(directoryName)",
            browserType: browserType,
            directoryName: directoryName,
            originalName: name,
            gaiaName: gaiaName,
            customAlias: userConfig?.alias,
            avatarImagePath: hasAvatar ? avatarPath : nil,
            avatarIconId: avatarIcon,
            lastUsedTime: lastUsed,
            isFavorite: userConfig?.isFavorite ?? false,
            launchConfig: userConfig?.launchConfig ?? .default,
            globalHotkey: userConfig?.globalHotkey
        )
    }
}

/// 用户自定义的 Profile 配置（存储在 config.json 中）
struct ProfileUserConfig: Codable {
    var alias: String?
    var isFavorite: Bool
    var launchConfig: LaunchConfig
    var globalHotkey: String?

    static let `default` = ProfileUserConfig(
        alias: nil,
        isFavorite: false,
        launchConfig: .default,
        globalHotkey: nil
    )
}
