import Foundation
import AppKit

/// Profile 扫描服务
class ProfileScanner {
    static let shared = ProfileScanner()

    private init() {}

    /// 扫描指定浏览器的所有 Profile
    func scanProfiles(
        for browserType: BrowserType,
        userConfigs: [String: ProfileUserConfig]
    ) -> [Profile] {
        let dataDir = browserType.dataDirectory

        guard FileManager.default.fileExists(atPath: dataDir) else {
            return []
        }

        // 读取 Local State 文件
        let localStatePath = "\(dataDir)/Local State"
        guard let localStateData = FileManager.default.contents(atPath: localStatePath),
              let localState = try? JSONSerialization.jsonObject(with: localStateData) as? [String: Any],
              let profileSection = localState["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: [String: Any]] else {
            // 如果无法读取 Local State，尝试直接扫描目录
            return scanProfilesFromDirectory(browserType: browserType, userConfigs: userConfigs)
        }

        var profiles: [Profile] = []

        for (directoryName, info) in infoCache {
            let profilePath = "\(dataDir)/\(directoryName)"
            guard FileManager.default.fileExists(atPath: profilePath) else {
                continue
            }

            let userConfig = userConfigs[directoryName]
            let profile = Profile.from(
                browserType: browserType,
                directoryName: directoryName,
                infoCache: info,
                userConfig: userConfig
            )
            profiles.append(profile)
        }

        // 按最后使用时间排序
        return profiles.sorted { p1, p2 in
            guard let t1 = p1.lastUsedTime else { return false }
            guard let t2 = p2.lastUsedTime else { return true }
            return t1 > t2
        }
    }

    /// 从目录直接扫描（备用方案）
    private func scanProfilesFromDirectory(
        browserType: BrowserType,
        userConfigs: [String: ProfileUserConfig]
    ) -> [Profile] {
        let dataDir = browserType.dataDirectory
        var profiles: [Profile] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dataDir)

            for item in contents {
                // 筛选 Profile 目录
                guard item == "Default" || item.hasPrefix("Profile ") else {
                    continue
                }

                let profilePath = "\(dataDir)/\(item)"
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: profilePath, isDirectory: &isDir),
                      isDir.boolValue else {
                    continue
                }

                // 尝试从 Preferences 读取名称
                let prefsPath = "\(profilePath)/Preferences"
                var name = item
                if let prefsData = FileManager.default.contents(atPath: prefsPath),
                   let prefs = try? JSONSerialization.jsonObject(with: prefsData) as? [String: Any],
                   let profileInfo = prefs["profile"] as? [String: Any],
                   let profileName = profileInfo["name"] as? String {
                    name = profileName
                }

                let userConfig = userConfigs[item]
                let avatarPath = "\(profilePath)/Google Profile Picture.png"
                let hasAvatar = FileManager.default.fileExists(atPath: avatarPath)

                let attrs = try? FileManager.default.attributesOfItem(atPath: profilePath)
                let lastUsed = attrs?[.modificationDate] as? Date

                let profile = Profile(
                    id: "\(browserType.rawValue)_\(item)",
                    browserType: browserType,
                    directoryName: item,
                    originalName: name,
                    customAlias: userConfig?.alias,
                    avatarImagePath: hasAvatar ? avatarPath : nil,
                    avatarIconId: nil,
                    lastUsedTime: lastUsed,
                    isFavorite: userConfig?.isFavorite ?? false,
                    launchConfig: userConfig?.launchConfig ?? .default,
                    globalHotkey: userConfig?.globalHotkey
                )
                profiles.append(profile)
            }
        } catch {
            print("Error scanning profiles: \(error)")
        }

        return profiles.sorted { p1, p2 in
            guard let t1 = p1.lastUsedTime else { return false }
            guard let t2 = p2.lastUsedTime else { return true }
            return t1 > t2
        }
    }

    /// 扫描所有已安装浏览器的 Profile
    func scanAllProfiles(userConfigs: [String: [String: ProfileUserConfig]]) -> [BrowserType: [Profile]] {
        var result: [BrowserType: [Profile]] = [:]

        for browserType in BrowserType.allCases {
            guard browserType.isInstalled && browserType.hasDataDirectory else {
                continue
            }

            let configs = userConfigs[browserType.rawValue] ?? [:]
            result[browserType] = scanProfiles(for: browserType, userConfigs: configs)
        }

        return result
    }

    /// 获取所有已安装的浏览器
    func getInstalledBrowsers() -> [Browser] {
        BrowserType.allCases
            .filter { $0.isInstalled }
            .map { Browser(type: $0) }
    }

    /// 获取当前活跃的 Profile（正在被 Chrome 使用）
    func getActiveProfiles(for browserType: BrowserType) -> [String] {
        let localStatePath = "\(browserType.dataDirectory)/Local State"

        guard let data = FileManager.default.contents(atPath: localStatePath),
              let localState = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = localState["profile"] as? [String: Any],
              let activeProfiles = profileSection["last_active_profiles"] as? [String] else {
            return []
        }

        return activeProfiles
    }

    /// 检查浏览器是否正在运行
    func isBrowserRunning(_ browserType: BrowserType) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == browserType.bundleIdentifier }
    }

    /// 检查特定 Profile 是否正在运行
    func isProfileRunning(_ profile: Profile) -> Bool {
        // 首先检查浏览器是否运行
        guard isBrowserRunning(profile.browserType) else {
            return false
        }

        // 检查是否在活跃 Profile 列表中
        let activeProfiles = getActiveProfiles(for: profile.browserType)
        return activeProfiles.contains(profile.directoryName)
    }
}
