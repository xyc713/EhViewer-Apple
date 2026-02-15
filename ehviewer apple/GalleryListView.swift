//
//  GalleryListView.swift
//  ehviewer apple
//
//  画廊列表视图 — 首页/热门/搜索结果
//

import SwiftUI
import EhModels
import EhAPI
import EhSettings
import EhDatabase
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct GalleryListView: View {
    let mode: ListMode

    enum ListMode {
        case home
        case popular
        case search(keyword: String)
        case tag(keyword: String)
        case favorites(slot: Int)
    }

    @State private var viewModel = GalleryListViewModel()
    @State private var showQuickSearch = false
    @State private var showAdvancedSearch = false
    @State private var advancedSearch = AdvancedSearchState()
    @State private var selectedQuickSearch: QuickSearchRecord?
    @State private var selectedGallery: GalleryInfo?

    /// 标签导航路径 — iPad 双栏布局中支持标签推入左侧
    @State private var sidebarPath = NavigationPath()

    /// 外部选择绑定（嵌入三栏布局时使用）
    private var externalSelection: Binding<GalleryInfo?>?
    private var isEmbedded: Bool { externalSelection != nil }

    /// 是否作为 push 目标（避免嵌套 NavigationStack）
    private var isPushed: Bool = false

    /// 收藏夹搜索关键字 (对齐 Android FavoritesScene 搜索)
    private var favSearchKeyword: String?

    private var selectionBinding: Binding<GalleryInfo?> {
        externalSelection ?? $selectedGallery
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 是否使用宽屏双栏布局 (考虑用户设置: wideScreenListMode)
    /// iPhone 手机端始终使用单栏布局，仅 iPad 在 regular 宽度时才启用双栏
    private var isRegularWidth: Bool {
        // 在 iPhone 上始终为 false (避免大屏 iPhone 横屏时误触发双栏)
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        return horizontalSizeClass == .regular && AppSettings.shared.wideScreenListMode == 0
    }
    #else
    /// macOS 也支持全宽单列表模式
    private var isRegularWidth: Bool { AppSettings.shared.wideScreenListMode == 0 }
    #endif

    init(mode: ListMode) {
        self.mode = mode
        self.externalSelection = nil
    }

    /// 作为导航目标推入时使用，不创建自己的 NavigationStack/SplitView
    init(mode: ListMode, isPushed: Bool) {
        self.mode = mode
        self.isPushed = isPushed
        self.externalSelection = nil
    }

    init(mode: ListMode, selection: Binding<GalleryInfo?>) {
        self.mode = mode
        self.externalSelection = selection
    }

    /// 收藏搜索模式
    init(mode: ListMode, searchKeyword: String?) {
        self.mode = mode
        self.favSearchKeyword = searchKeyword
        self.externalSelection = nil
    }

    /// 收藏搜索模式 (嵌入)
    init(mode: ListMode, selection: Binding<GalleryInfo?>, searchKeyword: String?) {
        self.mode = mode
        self.externalSelection = selection
        self.favSearchKeyword = searchKeyword
    }

    /// 当前实际运行模式 — 如果搜索框有内容，则为搜索模式 (对齐 Android: 搜索后跳页/翻页保持在搜索结果中)
    private var effectiveMode: ListMode {
        if !viewModel.searchText.isEmpty {
            return .search(keyword: viewModel.searchText)
        }
        return mode
    }



    var body: some View {
        Group {
            if isEmbedded {
                // 嵌入模式: 仅展示列表，由父视图管理导航
                embeddedContent
            } else if isPushed {
                // 被推入导航栈时: 不创建自己的 NavigationStack，避免嵌套
                pushedContent
        } else if isRegularWidth {
            // iPadOS / macOS 独立模式: 双栏布局
            NavigationSplitView {
                NavigationStack(path: $sidebarPath) {
                    sidebarContent
                        .navigationTitle(navigationTitle)
                        .navigationDestination(for: TagSearchDestination.self) { dest in
                            // 标签点击推入的画廊列表 (对齐 Android: onTagClick → 叠加新列表)
                            GalleryListView(mode: .tag(keyword: dest.tag), selection: $selectedGallery)
                        }
                }
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
            } detail: {
                // Detail 部分需要 NavigationStack 才能支持 navigationDestination
                NavigationStack {
                    if let gallery = selectedGallery {
                        GalleryDetailView(gallery: gallery)
                            .id(gallery.gid)  // 强制在选择变更时重新创建视图，修复封面不刷新问题
                    } else {
                        ContentUnavailableView("选择画廊", systemImage: "photo.stack", description: Text("从左侧列表选择一个画廊"))
                    }
                }
                .environment(\.tagNavigationAction, TagNavigationAction { tag in
                    sidebarPath.append(TagSearchDestination(tag: tag))
                })
            }
            .task {
                if viewModel.galleries.isEmpty {
                    viewModel.loadGalleries(mode: mode)
                }
            }
        } else {
            // iPhone: 单栏布局
            compactContent
        }
        }
        .onAppear {
            // 同步收藏搜索关键字到 ViewModel
            viewModel.favSearchKeyword = favSearchKeyword
            // 标签搜索: 将标签关键字放入搜索框 (对齐 Android: mSearchBar.setText(keyword))
            if case .tag(let keyword) = mode, viewModel.searchText.isEmpty {
                viewModel.searchText = keyword
            }
        }
        .onChange(of: showAdvancedSearch) { _, isShowing in
            if !isShowing {
                // 高级搜索面板关闭时，静默保存参数到 ViewModel (不自动触发搜索)
                // 用户提交搜索或点击搜索按钮时才会使用这些参数
                viewModel.syncAdvancedSettings(advancedSearch)
            }
        }
    }

    // iPhone 布局（原有实现）
    private var compactContent: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.galleries.isEmpty {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.galleries.isEmpty && viewModel.errorMessage != nil {
                    errorView
                } else {
                    galleryList
                }
            }
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 8) {
                        // 高级搜索 (对齐 Android AddDeleteDrawable: + icon)
                        Button {
                            showAdvancedSearch = true
                        } label: {
                            Image(systemName: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
                        }

                        Button {
                            showQuickSearch = true
                        } label: {
                            Image(systemName: "bookmark")
                        }

                        // 跳页按钮 (对齐 Android FAB position 1: Go to)
                        Button {
                            viewModel.showGoToDialog = true
                        } label: {
                            Image(systemName: "arrow.up.and.down.text.horizontal")
                        }
                        .disabled(viewModel.galleries.isEmpty)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索画廊...")
            .searchSuggestions {
                // 高级搜索快捷入口 (对齐 Android: 搜索框输入内容后右侧显示 + 按钮)
                Button {
                    showAdvancedSearch = true
                } label: {
                    Label("高级搜索筛选", systemImage: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
                }
                if !viewModel.suggestions.isEmpty {
                    searchSuggestionsContent
                }
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.updateSuggestions()
            }
            .onSubmit(of: .search) {
                viewModel.searchWithAdvanced(advancedSearch)
            }
            .rightDrawer(isOpen: $showQuickSearch) {
                QuickSearchDrawerContent(
                    selectedSearch: $selectedQuickSearch,
                    currentKeyword: viewModel.searchText,
                    onDismiss: { showQuickSearch = false }
                )
            }
            .sheet(isPresented: $showAdvancedSearch) {
                AdvancedSearchView(state: advancedSearch)
            }
            .onChange(of: selectedQuickSearch) { _, newValue in
                if let search = newValue {
                    viewModel.applyQuickSearch(search)
                    selectedQuickSearch = nil
                }
            }
        }
        .task {
            if viewModel.galleries.isEmpty {
                viewModel.loadGalleries(mode: mode)
            }
        }
        // 跳页对话框 (对齐 Android showPageJumpDialog)
        .alert("跳页", isPresented: $viewModel.showGoToDialog) {
            TextField("页码", text: $viewModel.goToPageInput)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button("取消", role: .cancel) {
                viewModel.goToPageInput = ""
            }
            Button("确定") {
                if let page = Int(viewModel.goToPageInput), page >= 1,
                   viewModel.totalPages <= 0 || page <= viewModel.totalPages {
                    viewModel.goToPage(page - 1, mode: effectiveMode)
                }
                viewModel.goToPageInput = ""
            }
        } message: {
            Text(viewModel.totalPages > 1 ? "输入页码 (1-\(viewModel.totalPages))" : "输入目标页码")
        }
    }

    /// 被推入导航栈时的内容 — 不包装 NavigationStack，避免嵌套
    private var pushedContent: some View {
        Group {
            if viewModel.isLoading && viewModel.galleries.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.galleries.isEmpty && viewModel.errorMessage != nil {
                errorView
            } else {
                galleryList
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Button {
                        showAdvancedSearch = true
                    } label: {
                        Image(systemName: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
                    }

                    Button {
                        showQuickSearch = true
                    } label: {
                        Image(systemName: "bookmark")
                    }

                    Button {
                        viewModel.showGoToDialog = true
                    } label: {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                    }
                    .disabled(viewModel.galleries.isEmpty)
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索画廊...")
        .searchSuggestions {
            // 高级搜索快捷入口 (对齐 Android: 搜索框输入内容后右侧显示 + 按钮)
            Button {
                showAdvancedSearch = true
            } label: {
                Label("高级搜索筛选", systemImage: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
            }
            if !viewModel.suggestions.isEmpty {
                searchSuggestionsContent
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.updateSuggestions()
        }
        .onSubmit(of: .search) {
            viewModel.searchWithAdvanced(advancedSearch)
        }
        .rightDrawer(isOpen: $showQuickSearch) {
            QuickSearchDrawerContent(
                selectedSearch: $selectedQuickSearch,
                currentKeyword: viewModel.searchText,
                onDismiss: { showQuickSearch = false }
            )
        }
        .sheet(isPresented: $showAdvancedSearch) {
            AdvancedSearchView(state: advancedSearch)
        }
        .onChange(of: selectedQuickSearch) { _, newValue in
            if let search = newValue {
                viewModel.applyQuickSearch(search)
                selectedQuickSearch = nil
            }
        }
        .task {
            if viewModel.galleries.isEmpty {
                viewModel.loadGalleries(mode: mode)
            }
        }
        .alert("跳页", isPresented: $viewModel.showGoToDialog) {
            TextField("页码", text: $viewModel.goToPageInput)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button("取消", role: .cancel) {
                viewModel.goToPageInput = ""
            }
            Button("确定") {
                if let page = Int(viewModel.goToPageInput), page >= 1,
                   viewModel.totalPages <= 0 || page <= viewModel.totalPages {
                    viewModel.goToPage(page - 1, mode: effectiveMode)
                }
                viewModel.goToPageInput = ""
            }
        } message: {
            Text(viewModel.totalPages > 1 ? "输入页码 (1-\(viewModel.totalPages))" : "输入目标页码")
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .home: return AppSettings.shared.gallerySite == .exHentai ? "ExHentai" : "E-Hentai"
        case .popular: return "热门"
        case .search(let kw): return "搜索: \(kw)"
        case .tag: return "标签搜索"  // 对齐 Android: 标签关键字显示在搜索框而非标题
        case .favorites: return "收藏"
        }
    }

    private var galleryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.galleries, id: \.gid) { gallery in
                    NavigationLink(value: gallery) {
                        GalleryRow(gallery: gallery)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 88)
                }

                // 加载更多
                if viewModel.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task {
                            await viewModel.loadMore(mode: effectiveMode)
                        }
                }
            }
        }
        .refreshable {
            viewModel.refresh(mode: effectiveMode)
        }
        .navigationDestination(for: GalleryInfo.self) { gallery in
            GalleryDetailView(gallery: gallery)
        }
    }

    // 嵌入模式内容（无导航包装器，用于三栏布局的 content 列）
    private var embeddedContent: some View {
        sidebarContent
            .navigationTitle(navigationTitle)
            .task {
                if viewModel.galleries.isEmpty {
                    viewModel.loadGalleries(mode: mode)
                }
            }
    }

    // iPad/Mac 侧边栏内容
    private var sidebarContent: some View {
        Group {
            if viewModel.isLoading && viewModel.galleries.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.galleries.isEmpty && viewModel.errorMessage != nil {
                errorView
            } else {
                List(selection: selectionBinding) {
                    ForEach(viewModel.galleries, id: \.gid) { gallery in
                        GalleryRow(gallery: gallery)
                            .tag(gallery)
                    }

                    if viewModel.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .task {
                                await viewModel.loadMore(mode: effectiveMode)
                            }
                    }
                }
                .listStyle(.sidebar)
                .refreshable {
                    viewModel.refresh(mode: effectiveMode)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Button {
                        showAdvancedSearch = true
                    } label: {
                        Image(systemName: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
                    }

                    Button {
                        showQuickSearch = true
                    } label: {
                        Image(systemName: "bookmark")
                    }

                    // 跳页按钮 (对齐 Android FAB position 1: Go to)
                    Button {
                        viewModel.showGoToDialog = true
                    } label: {
                        Image(systemName: "arrow.up.and.down.text.horizontal")
                    }
                    .disabled(viewModel.galleries.isEmpty)
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索画廊...")
        .searchSuggestions {
            // 高级搜索快捷入口 (对齐 Android: 搜索框输入内容后右侧显示 + 按钮)
            Button {
                showAdvancedSearch = true
            } label: {
                Label("高级搜索筛选", systemImage: advancedSearch.isEnabled ? "plus.circle.fill" : "plus.circle")
            }
            if !viewModel.suggestions.isEmpty {
                searchSuggestionsContent
            }
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.updateSuggestions()
        }
        .onSubmit(of: .search) {
            viewModel.searchWithAdvanced(advancedSearch)
        }
        .rightDrawer(isOpen: $showQuickSearch) {
            QuickSearchDrawerContent(
                selectedSearch: $selectedQuickSearch,
                currentKeyword: viewModel.searchText,
                onDismiss: { showQuickSearch = false }
            )
        }
        .sheet(isPresented: $showAdvancedSearch) {
            AdvancedSearchView(state: advancedSearch)
        }
        .onChange(of: selectedQuickSearch) { _, newValue in
            if let search = newValue {
                viewModel.applyQuickSearch(search)
                selectedQuickSearch = nil
            }
        }
        .alert("跳页", isPresented: $viewModel.showGoToDialog) {
            TextField("页码", text: $viewModel.goToPageInput)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button("取消", role: .cancel) {
                viewModel.goToPageInput = ""
            }
            Button("确定") {
                if let page = Int(viewModel.goToPageInput), page >= 1,
                   viewModel.totalPages <= 0 || page <= viewModel.totalPages {
                    viewModel.goToPage(page - 1, mode: effectiveMode)
                }
                viewModel.goToPageInput = ""
            }
        } message: {
            Text(viewModel.totalPages > 1 ? "输入页码 (1-\(viewModel.totalPages))" : "输入目标页码")
        }
    }

    // MARK: - 搜索建议内容 (对齐 Android SearchBar.updateSuggestions)

    @ViewBuilder
    private var searchSuggestionsContent: some View {
        ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { _, suggestion in
            Button {
                viewModel.applySuggestion(suggestion.english)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.chinese)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(suggestion.english)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.background)
            )
            .searchCompletion(suggestion.english)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(viewModel.errorMessage ?? "加载失败")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // 网络提示
            if let msg = viewModel.errorMessage,
               msg.contains("超时") || msg.contains("timed out") || msg.contains("连接") || msg.contains("域名") || msg.contains("DNS") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("请确认 VPN / 代理已开启", systemImage: "lock.shield")
                    Label("可在设置中尝试开启域名前置", systemImage: "server.rack")
                    Label("检查 DNS 是否被污染", systemImage: "globe")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            }

            Button("重试") {
                viewModel.loadGalleries(mode: effectiveMode)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - 星级评分视图 (对齐 Android SimpleRatingView)

struct SimpleRatingView: View {
    let rating: Float

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                starImage(for: index)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func starImage(for index: Int) -> Image {
        let threshold = Float(index) + 1
        if rating >= threshold {
            return Image(systemName: "star.fill")
        } else if rating >= threshold - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
}

// MARK: - Gallery Row (对齐 Android item_gallery_list.xml 布局)

struct GalleryRow: View {
    let gallery: GalleryInfo
    var onFavorite: ((GalleryInfo) -> Void)?
    var onDownload: ((GalleryInfo) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 缩略图 (对齐 Android @id/thumb)
            CachedAsyncImage(url: URL(string: gallery.thumb ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.secondarySystemBackground)
            }
            .frame(width: 76, height: 106)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // 信息区 (对齐 Android RelativeLayout 右侧元素)
            VStack(alignment: .leading, spacing: 0) {
                // 标题 (对齐 Android @id/title: alignParentTop, toRightOf thumb)
                Text(gallery.suitableTitle(preferJpn: AppSettings.shared.showJpnTitle))
                    .font(.subheadline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)

                // 上传者 (对齐 Android @id/uploader: below title)
                if let uploader = gallery.uploader {
                    Text(uploader)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                Spacer(minLength: 4)

                // 底部区域 — 评分 + 图标行 (对齐 Android rating + LinearLayout)
                HStack {
                    // 评分星星 (对齐 Android SimpleRatingView: above category)
                    SimpleRatingView(rating: gallery.rating)

                    Spacer(minLength: 4)

                    // 右侧图标 (对齐 Android LinearLayout: downloaded, favourited, simple_language, pages)
                    HStack(spacing: 6) {
                        if gallery.favoriteSlot >= 0 {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        if let lang = gallery.simpleLanguage, !lang.isEmpty {
                            Text(lang)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(gallery.pages)P")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 分类 + 发布时间 (对齐 Android category + posted)
                HStack {
                    // 分类标签 (对齐 Android @id/category: alignBottom thumb)
                    Text(gallery.category.name)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(gallery.category.color)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer(minLength: 4)

                    // 发布时间 (对齐 Android @id/posted: alignBottom thumb, alignParentRight)
                    if let posted = gallery.posted, !posted.isEmpty {
                        Text(posted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            // 收藏
            Button {
                onFavorite?(gallery)
            } label: {
                Label("收藏", systemImage: gallery.favoriteSlot >= 0 ? "heart.fill" : "heart")
            }

            // 下载
            Button {
                onDownload?(gallery)
            } label: {
                Label("下载", systemImage: "arrow.down.circle")
            }

            Divider()

            // 复制链接
            Button {
                let url = "https://e-hentai.org/g/\(gallery.gid)/\(gallery.token)/"
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                #else
                UIPasteboard.general.string = url
                #endif
            } label: {
                Label("复制链接", systemImage: "doc.on.doc")
            }

            // 分享 (仅 iOS)
            #if os(iOS)
            ShareLink(item: URL(string: "https://e-hentai.org/g/\(gallery.gid)/\(gallery.token)/")!) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            #endif
        }
    }
}

// MARK: - ViewModel

@Observable
class GalleryListViewModel {
    var galleries: [GalleryInfo] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = ""
    var hasMore = false
    var totalPages = 0 // 总页数 (对齐 Android mHelper.mPages)
    var showGoToDialog = false // 跳页对话框
    var goToPageInput: String = "" // 跳页输入

    /// 收藏夹搜索关键字 (由 FavoritesView 传入)
    var favSearchKeyword: String?

    // MARK: - 搜索建议 (对齐 Android SearchBar.updateSuggestions)
    var suggestions: [(chinese: String, english: String)] = []
    private var suggestionTask: Task<Void, Never>?

    /// 更新搜索建议 (对齐 Android SearchBar.updateSuggestions)
    func updateSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = Task { @MainActor in
            // 防抖 200ms
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            guard let extracted = EhTagDatabase.extractLastKeyword(from: searchText) else {
                suggestions = []
                return
            }
            let results = EhTagDatabase.shared.suggest(extracted.keyword)
            if !Task.isCancelled {
                suggestions = results
            }
        }
    }

    /// 应用搜索建议到搜索文本
    func applySuggestion(_ suggestion: String) {
        searchText = EhTagDatabase.applySuggestion(to: searchText, suggestion: suggestion)
        suggestions = []
    }

    private var currentPage = 0
    private var currentCacheKey: String?
    private var currentMode: GalleryListView.ListMode?
    /// 高级搜索参数 (对齐 Android AdvanceSearchTable 状态持久化)
    private var currentAdvanceSearch: Int = -1
    private var currentMinRating: Int = -1
    private var currentPageFrom: Int = -1
    private var currentPageTo: Int = -1
    private var currentCategory: Int = 0
    private var currentSearchMode: SearchMode = .normal

    func loadGalleries(mode: GalleryListView.ListMode) {
        guard !isLoading else { return }

        currentMode = mode
        
        // 先查缓存
        let cacheKey = Self.cacheKey(for: mode, page: 0)
        if let cached = GalleryCache.shared.getListResult(forKey: cacheKey) {
            galleries = cached.galleries
            hasMore = cached.hasMore
            totalPages = cached.totalPages ?? 0
            currentCacheKey = cacheKey
            return
        }

        isLoading = true
        errorMessage = nil
        currentPage = 0
        currentCacheKey = cacheKey

        Task {
            await fetchPage(mode: mode, page: 0)
        }
    }

    func refresh(mode: GalleryListView.ListMode) {
        // 刷新时清除当前 mode 的缓存
        if let key = currentCacheKey {
            GalleryCache.shared.removeListResult(forKey: key)
        }
        galleries = []
        loadGalleries(mode: mode)
    }

    func search() {
        guard !searchText.isEmpty else { return }
        galleries = []
        isLoading = true
        errorMessage = nil
        currentPage = 0
        // 清除高级搜索参数
        currentAdvanceSearch = -1
        currentMinRating = -1
        currentPageFrom = -1
        currentPageTo = -1
        currentCategory = 0
        currentSearchMode = .normal

        Task {
            await fetchPage(mode: .search(keyword: searchText), page: 0)
        }
    }

    /// 带高级搜索参数的搜索 (对齐 Android AdvanceSearchTable → ListUrlBuilder)
    func searchWithAdvanced(_ state: AdvancedSearchState) {
        currentAdvanceSearch = state.advanceSearchValue
        currentMinRating = state.minRatingValue
        currentPageFrom = state.pageFromValue
        currentPageTo = state.pageToValue
        currentCategory = state.categoryValue
        currentSearchMode = state.searchMode

        // 没有关键字时，按分类过滤首页 (对齐 Android: 无关键字也能按分类搜索)
        if searchText.isEmpty {
            galleries = []
            isLoading = true
            errorMessage = nil
            currentPage = 0
            Task {
                await fetchPage(mode: .home, page: 0)
            }
            return
        }

        galleries = []
        isLoading = true
        errorMessage = nil
        currentPage = 0
        Task {
            await fetchPage(mode: .search(keyword: searchText), page: 0)
        }
    }

    /// 高级搜索面板关闭后自动应用设置 (对齐 Android GalleryListScene.onApplySearch)
    func applyAdvancedSettings(_ state: AdvancedSearchState, initialMode: GalleryListView.ListMode) {
        syncAdvancedSettings(state)

        // 清除缓存，强制使用新参数重新加载
        if let key = currentCacheKey {
            GalleryCache.shared.removeListResult(forKey: key)
        }

        // 有活跃搜索关键字时，重新执行搜索
        if !searchText.isEmpty {
            galleries = []
            isLoading = true
            errorMessage = nil
            currentPage = 0
            Task {
                await fetchPage(mode: .search(keyword: searchText), page: 0)
            }
            return
        }

        // 首页模式: 用分类重新加载
        if case .home = initialMode {
            galleries = []
            isLoading = true
            errorMessage = nil
            currentPage = 0
            Task {
                await fetchPage(mode: .home, page: 0)
            }
        }
    }

    /// 静默同步高级搜索参数到 ViewModel (不触发搜索)
    func syncAdvancedSettings(_ state: AdvancedSearchState) {
        currentCategory = state.categoryValue
        currentSearchMode = state.searchMode
        currentAdvanceSearch = state.advanceSearchValue
        currentMinRating = state.minRatingValue
        currentPageFrom = state.pageFromValue
        currentPageTo = state.pageToValue
    }

    func applyQuickSearch(_ search: QuickSearchRecord) {
        guard let keyword = search.keyword, !keyword.isEmpty else { return }
        searchText = keyword
        galleries = []
        isLoading = true
        errorMessage = nil
        currentPage = 0

        // 构建带有分类和评分过滤的搜索
        Task {
            await fetchQuickSearch(search)
        }
    }

    private func fetchQuickSearch(_ search: QuickSearchRecord) async {
        do {
            let site = AppSettings.shared.gallerySite
            let host = EhURL.host(for: site)

            var urlComponents = URLComponents(string: host)!
            var queryItems: [URLQueryItem] = []

            // 关键词
            if let keyword = search.keyword {
                queryItems.append(URLQueryItem(name: "f_search", value: keyword))
            }

            // 分类过滤 (E-Hentai 使用 f_cats 参数，是要排除的分类的位掩码)
            if search.category > 0 {
                // category 是要包含的分类，需要计算排除的分类
                let allCategories = 0x3FF  // 全部分类
                let excludeCategories = allCategories ^ search.category
                queryItems.append(URLQueryItem(name: "f_cats", value: String(excludeCategories)))
            }

            // 最低评分
            if search.minRating > 0 {
                queryItems.append(URLQueryItem(name: "f_srdd", value: String(search.minRating)))
                queryItems.append(URLQueryItem(name: "f_sr", value: "on"))
            }

            // 高级搜索标记
            if search.advanceSearch > 0 || search.minRating > 0 {
                queryItems.append(URLQueryItem(name: "advsearch", value: "1"))
            }

            urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

            let result = try await EhAPI.shared.getGalleryList(url: urlComponents.url!.absoluteString)

            await MainActor.run {
                self.galleries = result.galleries
                self.hasMore = result.nextPage != nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = EhError.localizedMessage(for: error)
                self.isLoading = false
            }
        }
    }

    func loadMore(mode: GalleryListView.ListMode) async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        currentPage += 1
        await fetchPage(mode: mode, page: currentPage)
    }
    
    /// 跳转到指定页 (对齐 Android ContentHelper.goTo(page))
    func goToPage(_ page: Int, mode: GalleryListView.ListMode) {
        guard page >= 0 && page < totalPages else { return }
        
        galleries = []
        isLoading = true
        errorMessage = nil
        currentPage = page
        currentMode = mode
        
        Task {
            await fetchPage(mode: mode, page: page)
        }
    }

    private func fetchPage(mode: GalleryListView.ListMode, page: Int) async {
        do {
            let site = AppSettings.shared.gallerySite
            let host = EhURL.host(for: site)
            let urlString: String

            switch mode {
            case .home:
                var builder = ListUrlBuilder()
                builder.mode = .normal
                builder.pageIndex = page
                builder.category = currentCategory
                urlString = builder.build(site: site)
            case .popular:
                urlString = EhURL.popularUrl(for: site)
            case .search(let keyword):
                var builder = ListUrlBuilder()
                builder.mode = ListUrlBuilder.Mode(rawValue: currentSearchMode.listMode) ?? .normal
                builder.keyword = keyword
                builder.pageIndex = page
                builder.advanceSearch = currentAdvanceSearch
                builder.minRating = currentMinRating
                builder.pageFrom = currentPageFrom
                builder.pageTo = currentPageTo
                builder.category = currentCategory
                urlString = builder.build(site: site)
            case .tag(let keyword):
                let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? keyword
                if page > 0 {
                    urlString = "\(host)tag/\(encoded)/\(page)"
                } else {
                    urlString = "\(host)tag/\(encoded)"
                }
            case .favorites(let slot):
                // slot -1 = 全部收藏, 0-9 = 指定收藏夹 (对齐 Android FavoritesScene)
                var favUrl: String
                if slot < 0 {
                    favUrl = "\(EhURL.favoritesUrl(for: site))?page=\(page)"
                } else {
                    favUrl = "\(EhURL.favoritesUrl(for: site))?favcat=\(slot)&page=\(page)"
                }
                // 收藏搜索 (对齐 Android FavoritesScene.onGetFavoritesSuccess)
                if let keyword = favSearchKeyword, !keyword.isEmpty {
                    let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
                    favUrl += "&f_search=\(encoded)"
                }
                urlString = favUrl
            }

            let result = try await EhAPI.shared.getGalleryList(url: urlString)

            await MainActor.run {
                if page == 0 {
                    self.galleries = result.galleries
                } else {
                    self.galleries.append(contentsOf: result.galleries)
                }
                self.hasMore = result.nextPage != nil
                // 解析总页数 (对齐 Android: GalleryListParser 返回的 pages)
                self.totalPages = result.pages
                self.isLoading = false

                // 缓存第一页结果
                if page == 0 {
                    let cacheKey = Self.cacheKey(for: mode, page: 0)
                    GalleryCache.shared.putListResult(
                        CachedGalleryListResult(
                            galleries: self.galleries,
                            hasMore: self.hasMore,
                            nextPage: result.nextPage,
                            totalPages: self.totalPages
                        ),
                        forKey: cacheKey
                    )
                }
            }

        } catch {
            await MainActor.run {
                self.errorMessage = EhError.localizedMessage(for: error)
                self.isLoading = false
            }
        }
    }

    /// 生成缓存 key
    private static func cacheKey(for mode: GalleryListView.ListMode, page: Int) -> String {
        switch mode {
        case .home: return "home:\(page)"
        case .popular: return "popular:\(page)"
        case .search(let kw): return "search:\(kw):\(page)"
        case .tag(let kw): return "tag:\(kw):\(page)"
        case .favorites(let slot): return "fav:\(slot):\(page)"
        }
    }
}

#if os(iOS)
// iOS already has secondarySystemBackground
#else
extension NSColor {
    static var secondarySystemBackground: NSColor { .controlBackgroundColor }
}
#endif

// MARK: - Right Drawer Overlay (对齐 Android EhDrawerLayout 右侧抽屉)

struct RightDrawerOverlay<DrawerContent: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let drawerContent: () -> DrawerContent

    private let drawerWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .trailing) {
            // 半透明遮罩
            Color.black
                .opacity(isOpen ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isOpen = false
                    }
                }
                .allowsHitTesting(isOpen)

            // 右侧边缘滑动感应区 (关闭时: 从右向左滑动打开抽屉)
            if !isOpen {
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if value.translation.width < -50 {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isOpen = true
                                        }
                                    }
                                }
                        )
                }
            }

            // 抽屉面板
            drawerContent()
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.regularMaterial)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12))
                .shadow(color: .black.opacity(isOpen ? 0.15 : 0), radius: 8, x: -3)
                .offset(x: isOpen ? 0 : drawerWidth)
        }
        .animation(.easeInOut(duration: 0.25), value: isOpen)
    }
}

extension View {
    /// 右侧抽屉修饰器 (对齐 Android EhDrawerLayout)
    func rightDrawer<Content: View>(isOpen: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.overlay {
            RightDrawerOverlay(isOpen: isOpen, drawerContent: content)
        }
    }
}

#Preview {
    GalleryListView(mode: .home)
}
