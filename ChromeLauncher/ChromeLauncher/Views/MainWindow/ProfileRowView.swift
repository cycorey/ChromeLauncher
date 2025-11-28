import SwiftUI

/// Profile 行视图
struct ProfileRowView: View {
    let profile: Profile
    let onLaunch: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // 收藏标记
            Button {
                appState.toggleFavorite(profile: profile)
            } label: {
                Image(systemName: profile.isFavorite ? "star.fill" : "star")
                    .foregroundColor(profile.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(profile.isFavorite ? "取消收藏" : "添加到收藏")

            // 头像
            ProfileAvatarView(profile: profile, size: 36)

            // Profile 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    // 运行状态
                    if appState.isProfileRunning(profile) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("运行中")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(profile.directoryName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastUsed = profile.lastUsedTime {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(lastUsed.relativeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // 启动按钮（悬停时显示）
            if isHovering {
                Button {
                    onLaunch()
                } label: {
                    Image(systemName: "play.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("启动此 Profile")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contentShape(Rectangle())  // 确保整行可点击
    }
}

/// Profile 头像视图
struct ProfileAvatarView: View {
    let profile: Profile
    let size: CGFloat

    var body: some View {
        Group {
            if let image = profile.avatarImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Date Extension

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    VStack {
        ProfileRowView(
            profile: Profile(
                id: "test",
                browserType: .chrome,
                directoryName: "Profile 62",
                originalName: "Test Profile",
                gaiaName: "test@gmail.com",
                customAlias: nil,
                avatarImagePath: nil,
                avatarIconId: nil,
                lastUsedTime: Date().addingTimeInterval(-3600),
                isFavorite: true,
                launchConfig: .default,
                globalHotkey: nil
            ),
            onLaunch: {}
        )
    }
    .padding()
    .environmentObject(AppState.shared)
}
