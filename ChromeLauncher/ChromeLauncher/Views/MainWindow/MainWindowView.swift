import SwiftUI

/// 主窗口视图
struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProfileId: String?
    @State private var showingCreateSheet = false
    @State private var showingDeleteAlert = false
    @State private var profileToDelete: Profile?
    @State private var activeFilterId: Int? = nil  // 当前激活的快速过滤按钮

    /// 当前选中的 Profile
    private var selectedProfile: Profile? {
        guard let id = selectedProfileId else { return nil }
        for profiles in appState.profilesByBrowser.values {
            if let profile = profiles.first(where: { $0.id == id }) {
                return profile
            }
        }
        return nil
    }

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
                        .frame(width: 400)
                        .id(profile.id)  // 强制刷新
                } else {
                    emptyDetailView
                        .frame(width: 400)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onExitCommand {
            // ESC 关闭窗口
            NSApp.keyWindow?.close()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProfileSheet()
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let profile = profileToDelete {
                    _ = appState.deleteProfile(profile)
                    selectedProfileId = nil
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("确定要删除 Profile \"\(profile.displayName)\" 吗？\n\n此操作会将 Profile 移至废纸篓，包括其中的所有数据（书签、历史记录、扩展等）。")
            }
        }
        // ⌘1-9 快速过滤快捷键
        .onKeyPress(phases: .down) { press in
            guard press.modifiers == .command else { return .ignored }
            let keyChar = press.key.character
            guard let number = Int(String(keyChar)), number >= 1, number <= 9 else { return .ignored }

            let allFilters = ConfigManager.shared.getQuickFilters()
            if let filter = allFilters.first(where: { $0.id == number && $0.isEnabled }) {
                applyQuickFilter(filter)
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Subviews

    /// 快速过滤按钮
    private var quickFilters: [QuickFilter] {
        ConfigManager.shared.getQuickFilters().filter { $0.isEnabled }
    }

    /// 顶部工具栏
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 快速过滤按钮组
            quickFilterButtons

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索 Profile...", text: $appState.searchText)
                    .textFieldStyle(.plain)

                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                        activeFilterId = nil
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

    /// 快速过滤按钮组
    @ViewBuilder
    private var quickFilterButtons: some View {
        let allFilters = ConfigManager.shared.getQuickFilters()
        let enabledFilters = allFilters.filter { $0.isEnabled }

        if !enabledFilters.isEmpty {
            HStack(spacing: 4) {
                ForEach(enabledFilters) { filter in
                    QuickFilterButton(
                        filter: filter,
                        isActive: activeFilterId == filter.id
                    ) {
                        applyQuickFilter(filter)
                    }
                }
            }
        }
    }

    /// 应用快速过滤
    private func applyQuickFilter(_ filter: QuickFilter) {
        if activeFilterId == filter.id {
            // 再次点击取消过滤
            appState.searchText = ""
            activeFilterId = nil
        } else {
            appState.searchText = filter.text
            activeFilterId = filter.id
        }
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
                    appState.selectedBrowserType = browserType
                    selectedProfileId = nil
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
                List(appState.filteredProfiles, id: \.id, selection: $selectedProfileId) { profile in
                    ProfileRowView(profile: profile) {
                        appState.launch(profile: profile)
                    }
                    .tag(profile.id)
                    .contextMenu {
                        profileContextMenu(for: profile)
                    }
                }
                .onTapGesture(count: 2) {
                    // 双击启动选中的 Profile
                    if let profile = selectedProfile {
                        appState.launch(profile: profile)
                    }
                }
                .listStyle(.inset)
                .onKeyPress(.return) {
                    // 回车键启动选中的 Profile
                    if let profile = selectedProfile {
                        appState.launch(profile: profile)
                        return .handled
                    }
                    return .ignored
                }
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
            appState.launchIncognito(profile: profile)
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

        // 打开 Profile 文件夹
        Button {
            let url = URL(fileURLWithPath: profile.fullPath)
            NSWorkspace.shared.open(url)
        } label: {
            Label("在 Finder 中显示", systemImage: "folder")
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

/// 快速过滤按钮
struct QuickFilterButton: View {
    let filter: QuickFilter
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(filter.text)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help("⌘\(filter.id) - 过滤: \(filter.text)")
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AppState.shared)
}
