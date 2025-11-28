import SwiftUI

/// 主窗口视图
struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProfile: Profile?
    @State private var showingCreateSheet = false
    @State private var showingDeleteAlert = false
    @State private var profileToDelete: Profile?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarView

            Divider()

            // 浏览器选择器
            browserSelector

            Divider()

            // 主内容区
            HSplitView {
                // 左侧: Profile 列表
                profileListView
                    .frame(minWidth: 300)

                // 右侧: 详情/选项面板
                if let profile = selectedProfile {
                    ProfileDetailView(profile: profile)
                        .frame(minWidth: 250)
                } else {
                    emptyDetailView
                        .frame(minWidth: 250)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showingCreateSheet) {
            CreateProfileSheet()
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let profile = profileToDelete {
                    _ = appState.deleteProfile(profile)
                    selectedProfile = nil
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("确定要删除 Profile \"\(profile.displayName)\" 吗？\n\n此操作会将 Profile 移至废纸篓，包括其中的所有数据（书签、历史记录、扩展等）。")
            }
        }
    }

    // MARK: - Subviews

    /// 顶部工具栏
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索 Profile...", text: $appState.searchText)
                    .textFieldStyle(.plain)

                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)

            Spacer()

            // 刷新按钮
            Button {
                appState.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新 Profile 列表")

            // 新建 Profile 按钮
            Button {
                showingCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("新建 Profile")
        }
        .padding()
    }

    /// 浏览器选择器
    private var browserSelector: some View {
        HStack(spacing: 4) {
            ForEach(BrowserType.allCases.filter { $0.isInstalled }) { browserType in
                BrowserTab(
                    browserType: browserType,
                    isSelected: appState.selectedBrowserType == browserType,
                    profileCount: appState.profilesByBrowser[browserType]?.count ?? 0
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedBrowserType = browserType
                        selectedProfile = nil
                    }
                }
            }

            Spacer()

            // Profile 统计
            Text("\(appState.totalProfileCount) 个 Profile")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor))
    }

    /// Profile 列表
    private var profileListView: some View {
        VStack(spacing: 0) {
            if appState.filteredProfiles.isEmpty {
                emptyListView
            } else {
                List(appState.filteredProfiles, selection: $selectedProfile) { profile in
                    ProfileRowView(profile: profile) {
                        appState.launch(profile: profile)
                    }
                    .contextMenu {
                        profileContextMenu(for: profile)
                    }
                    .tag(profile)
                }
                .listStyle(.inset)
            }
        }
    }

    /// 空列表视图
    private var emptyListView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(appState.searchText.isEmpty ? "暂无 Profile" : "未找到匹配的 Profile")
                .font(.headline)
                .foregroundColor(.secondary)

            if appState.searchText.isEmpty {
                Button("新建 Profile") {
                    showingCreateSheet = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 空详情视图
    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("选择一个 Profile 查看详情")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Profile 右键菜单
    @ViewBuilder
    private func profileContextMenu(for profile: Profile) -> some View {
        Button {
            appState.launch(profile: profile)
        } label: {
            Label("启动", systemImage: "play.fill")
        }

        Button {
            appState.launch(profile: profile, withBrowser: nil)
        } label: {
            Label("无痕模式启动", systemImage: "eye.slash")
        }

        Divider()

        Button {
            appState.toggleFavorite(profile: profile)
        } label: {
            Label(
                profile.isFavorite ? "取消收藏" : "添加到收藏",
                systemImage: profile.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        // 用其他浏览器打开
        Menu("用其他浏览器打开") {
            ForEach(BrowserType.allCases.filter { $0.isInstalled && $0 != profile.browserType }) { browserType in
                Button {
                    appState.launch(profile: profile, withBrowser: browserType)
                } label: {
                    Label(browserType.displayName, systemImage: "globe")
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            profileToDelete = profile
            showingDeleteAlert = true
        } label: {
            Label("删除 Profile", systemImage: "trash")
        }
    }
}

/// 浏览器标签页
struct BrowserTab: View {
    let browserType: BrowserType
    let isSelected: Bool
    let profileCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = browserType.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }

                Text(browserType.shortName)
                    .fontWeight(isSelected ? .semibold : .regular)

                Text("\(profileCount)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState.shared)
}
