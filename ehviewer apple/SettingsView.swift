//
//  SettingsView.swift
//  ehviewer apple
//
//  设置视图
//

import SwiftUI
import EhSettings
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @State private var vm = SettingsViewModel()
    @Environment(\.openURL) private var openURL

    /// 被推入父导航栈时，不创建自己的 NavigationStack，避免嵌套
    private var isPushed: Bool = false

    init(isPushed: Bool = false) {
        self.isPushed = isPushed
    }

    var body: some View {
        if isPushed {
            settingsInnerContent
        } else {
            NavigationStack {
                settingsInnerContent
            }
        }
    }

    private var settingsInnerContent: some View {
        Form {
            accountSection
            siteSection
            displaySection
            favoritesSection
            networkSection
            readingSection
            downloadSection
            cacheSection
            securitySection
            advancedSection
            aboutSection
        }
        .navigationTitle("设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - Account

    private var accountSection: some View {
        Section("账号") {
            if vm.isLoggedIn {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading) {
                        Text("已登录")
                            .font(.subheadline.bold())
                        Text(vm.hasExAccess ? "ExHentai 可用" : "仅 E-Hentai")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("注销", role: .destructive) {
                    vm.showLogoutConfirm = true
                }
            } else {
                Button("登录") {
                    vm.showLogin = true
                }
            }
        }
        .confirmationDialog("确认注销？", isPresented: $vm.showLogoutConfirm, titleVisibility: .visible) {
            Button("注销", role: .destructive) {
                vm.logout()
            }
        }
        .sheet(isPresented: $vm.showLogin) {
            LoginView()
        }
    }

    // MARK: - Site

    private var siteSection: some View {
        Section("站点") {
            Picker("默认站点", selection: $vm.gallerySite) {
                Text("E-Hentai").tag(0)
                Text("ExHentai").tag(1)
            }

            Picker("列表模式", selection: $vm.listMode) {
                Text("列表").tag(0)
                Text("紧凑").tag(1)
                Text("网格").tag(2)
            }

            Toggle("显示日文标题", isOn: $vm.showJpnTitle)

            // 标签翻译设置
            Toggle("显示标签翻译", isOn: $vm.showTagTranslations)
            
            if vm.showTagTranslations {
                HStack {
                    Text("标签数据库")
                    Spacer()
                    if vm.isUpdatingTagDb {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(vm.tagDbStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    Task { await vm.updateTagDatabase() }
                } label: {
                    HStack {
                        Text("更新标签翻译数据库")
                        Spacer()
                        if vm.tagDbUpdateSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .disabled(vm.isUpdatingTagDb)
            }

            NavigationLink("标签过滤") {
                FilterView()
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        Section("网络") {
            Toggle("域名前置", isOn: $vm.domainFronting)

            Toggle("DNS over HTTPS", isOn: $vm.dnsOverHttps)

            Toggle("内置 Hosts", isOn: $vm.builtInHosts)
            
            // 网络诊断按钮
            Button {
                vm.runNetworkDiagnostics()
            } label: {
                HStack {
                    Text("网络诊断")
                    Spacer()
                    if vm.isDiagnosing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !vm.diagnosisResult.isEmpty {
                        Image(systemName: vm.diagnosisSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(vm.diagnosisSuccess ? .green : .orange)
                    }
                }
            }
            .disabled(vm.isDiagnosing)
            
            if !vm.diagnosisResult.isEmpty {
                Text(vm.diagnosisResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Display (对齐 Android Settings: 外观)

    private var displaySection: some View {
        Section("外观") {
            // 深色模式 (对齐 Android Settings.KEY_THEME)
            Picker("主题", selection: Binding(
                get: { AppSettings.shared.theme },
                set: { AppSettings.shared.theme = $0 }
            )) {
                Text("跟随系统").tag(0)
                Text("浅色").tag(1)
                Text("深色").tag(2)
            }

            // 启动页面 (对齐 Android Settings.KEY_LAUNCH_PAGE)
            Picker("启动页面", selection: Binding(
                get: { AppSettings.shared.launchPage },
                set: { AppSettings.shared.launchPage = $0 }
            )) {
                Text("首页").tag(0)
                Text("热门").tag(1)
                Text("排行榜").tag(2)
                Text("收藏").tag(3)
                Text("下载").tag(4)
                Text("历史").tag(5)
            }

            Toggle("显示画廊页数", isOn: Binding(
                get: { AppSettings.shared.showGalleryPages },
                set: { AppSettings.shared.showGalleryPages = $0 }
            ))

            Toggle("显示评论区", isOn: Binding(
                get: { AppSettings.shared.showGalleryComment },
                set: { AppSettings.shared.showGalleryComment = $0 }
            ))

            Toggle("显示评分", isOn: Binding(
                get: { AppSettings.shared.showGalleryRating },
                set: { AppSettings.shared.showGalleryRating = $0 }
            ))

            Toggle("显示阅读进度", isOn: Binding(
                get: { AppSettings.shared.showReadProgress },
                set: { AppSettings.shared.showReadProgress = $0 }
            ))

            // 缩略图大小 (对齐 Android Settings.KEY_THUMB_SIZE)
            Picker("缩略图大小", selection: Binding(
                get: { AppSettings.shared.thumbSize },
                set: { AppSettings.shared.thumbSize = $0 }
            )) {
                Text("小").tag(0)
                Text("中").tag(1)
                Text("大").tag(2)
            }

            // 大屏幕列表布局 (对齐 Android: 全宽单列表布局选项)
            Picker("宽屏布局", selection: Binding(
                get: { AppSettings.shared.wideScreenListMode },
                set: { AppSettings.shared.wideScreenListMode = $0 }
            )) {
                Text("双栏 (列表+详情)").tag(0)
                Text("全宽单列表").tag(1)
            }
        }
    }

    // MARK: - Favorites (对齐 Android Settings: 收藏)

    private var favoritesSection: some View {
        Section("收藏") {
            // 默认收藏夹 (对齐 Android Settings.KEY_DEFAULT_FAV_SLOT)
            Picker("默认收藏夹", selection: Binding(
                get: { AppSettings.shared.defaultFavSlot },
                set: { AppSettings.shared.defaultFavSlot = $0 }
            )) {
                Text("每次询问").tag(-2)
                ForEach(0..<10) { slot in
                    Text(AppSettings.shared.favCatName(slot)).tag(slot)
                }
            }

            NavigationLink("收藏夹名称") {
                favCatNamesView
            }
        }
    }

    private var favCatNamesView: some View {
        List {
            ForEach(0..<10, id: \.self) { slot in
                HStack {
                    Text("收藏夹 \(slot)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("名称", text: Binding(
                        get: { AppSettings.shared.favCatName(slot) },
                        set: { AppSettings.shared.setFavCatName(slot, $0) }
                    ))
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("收藏夹名称")
    }

    // MARK: - Reading

    private var readingSection: some View {
        Section("阅读") {
            // 阅读方向 (对齐 Android Settings.KEY_READING_DIRECTION)
            Picker("阅读方向", selection: Binding(
                get: { AppSettings.shared.readingDirection },
                set: { AppSettings.shared.readingDirection = $0 }
            )) {
                Text("左→右").tag(0)
                Text("右→左").tag(1)
                Text("上→下").tag(2)
                Text("滚动模式").tag(3)
            }

            // 页面缩放 (对齐 Android Settings.KEY_PAGE_SCALING)
            Picker("页面缩放", selection: Binding(
                get: { AppSettings.shared.pageScaling },
                set: { AppSettings.shared.pageScaling = $0 }
            )) {
                Text("适合屏幕").tag(0)
                Text("适合宽度").tag(1)
                Text("适合高度").tag(2)
                Text("原始大小").tag(3)
                Text("等比缩放").tag(4)
            }

            // 起始位置 (对齐 Android Settings.KEY_START_POSITION)
            Picker("起始位置", selection: Binding(
                get: { AppSettings.shared.startPosition },
                set: { AppSettings.shared.startPosition = $0 }
            )) {
                Text("默认").tag(0)
                Text("顶部").tag(1)
                Text("右上").tag(2)
                Text("底部").tag(3)
                Text("右下").tag(4)
                Text("居中").tag(5)
            }

            // 屏幕旋转 (对齐 Android Settings.KEY_SCREEN_ROTATION)
            Picker("屏幕旋转", selection: Binding(
                get: { AppSettings.shared.screenRotation },
                set: { AppSettings.shared.screenRotation = $0 }
            )) {
                Text("跟随系统").tag(0)
                Text("竖屏锁定").tag(1)
                Text("横屏锁定").tag(2)
            }

            Stepper("预加载页数: \(vm.preloadImage)", value: $vm.preloadImage, in: 1...10)

            Toggle("保持屏幕常亮", isOn: $vm.keepScreenOn)

            Toggle("全屏阅读", isOn: Binding(
                get: { AppSettings.shared.readingFullscreen },
                set: { AppSettings.shared.readingFullscreen = $0 }
            ))

            Toggle("显示时钟", isOn: Binding(
                get: { AppSettings.shared.showClock },
                set: { AppSettings.shared.showClock = $0 }
            ))

            Toggle("显示进度", isOn: Binding(
                get: { AppSettings.shared.showProgress },
                set: { AppSettings.shared.showProgress = $0 }
            ))

            Toggle("显示电量", isOn: Binding(
                get: { AppSettings.shared.showBattery },
                set: { AppSettings.shared.showBattery = $0 }
            ))

            Toggle("显示页间距", isOn: Binding(
                get: { AppSettings.shared.showPageInterval },
                set: { AppSettings.shared.showPageInterval = $0 }
            ))

            #if os(iOS)
            Toggle("音量键翻页", isOn: Binding(
                get: { AppSettings.shared.volumePage },
                set: { AppSettings.shared.volumePage = $0 }
            ))

            if AppSettings.shared.volumePage {
                // 反转音量键 (对齐 Android Settings.KEY_READING_DIRECTION 反转)
                Toggle("反转音量键方向", isOn: Binding(
                    get: { AppSettings.shared.reverseVolumePage },
                    set: { AppSettings.shared.reverseVolumePage = $0 }
                ))
            }
            #endif

            // 自定义亮度 (对齐 Android Settings.KEY_CUSTOM_SCREEN_LIGHTNESS)
            Toggle("自定义亮度", isOn: Binding(
                get: { AppSettings.shared.customScreenLightness },
                set: { AppSettings.shared.customScreenLightness = $0 }
            ))

            if AppSettings.shared.customScreenLightness {
                Slider(value: Binding(
                    get: { Double(AppSettings.shared.screenLightness) },
                    set: { AppSettings.shared.screenLightness = Int($0) }
                ), in: 0...100, step: 1) {
                    Text("亮度: \(AppSettings.shared.screenLightness)%")
                }
            }

            // 自动翻页间隔 (对齐 Android Settings.KEY_AUTO_PAGE_INTERVAL)
            Stepper("自动翻页间隔: \(AppSettings.shared.autoPageInterval)s", value: Binding(
                get: { AppSettings.shared.autoPageInterval },
                set: { AppSettings.shared.autoPageInterval = $0 }
            ), in: 1...60)

            Toggle("色彩滤镜 (护眼)", isOn: Binding(
                get: { AppSettings.shared.colorFilter },
                set: { AppSettings.shared.colorFilter = $0 }
            ))
        }
    }

    // MARK: - Download

    private var downloadSection: some View {
        Section("下载") {
            #if os(macOS)
            // macOS: 自定义下载路径
            HStack {
                Text("下载位置")
                Spacer()
                Text(vm.downloadPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("更改...") {
                    vm.chooseDownloadPath()
                }
                .buttonStyle(.link)
            }
            #endif

            Stepper("并发线程: \(vm.multiThread)", value: $vm.multiThread, in: 1...5)

            Stepper("超时 (秒): \(vm.downloadTimeout)", value: $vm.downloadTimeout, in: 10...120, step: 10)

            // 下载延迟 (对齐 Android Settings.KEY_DOWNLOAD_DELAY)
            Stepper("下载延迟: \(AppSettings.shared.downloadDelay) ms", value: Binding(
                get: { AppSettings.shared.downloadDelay },
                set: { AppSettings.shared.downloadDelay = $0 }
            ), in: 0...2000, step: 100)

            // 图片分辨率设置 (对齐 Android Settings.KEY_IMAGE_RESOLUTION)
            Picker("图片分辨率", selection: Binding(
                get: { AppSettings.shared.imageResolution },
                set: { AppSettings.shared.imageResolution = $0 }
            )) {
                ForEach(ImageResolution.allCases) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }

            // 下载原图 (对齐 Android Settings.KEY_DOWNLOAD_ORIGIN_IMAGE)
            Toggle("下载原始图片", isOn: Binding(
                get: { AppSettings.shared.downloadOriginImage },
                set: { AppSettings.shared.downloadOriginImage = $0 }
            ))
        }
    }

    // MARK: - Cache

    private var cacheSection: some View {
        Section("缓存") {
            HStack {
                Text("磁盘缓存")
                Spacer()
                Text(vm.diskCacheSize)
                    .foregroundStyle(.secondary)
            }

            Button("清除缓存") {
                vm.clearCache()
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("隐私与安全") {
            Toggle("启用应用锁", isOn: Binding(
                get: { AppSettings.shared.enableSecurity },
                set: { AppSettings.shared.enableSecurity = $0 }
            ))

            if AppSettings.shared.enableSecurity {
                Picker("解锁延迟", selection: Binding(
                    get: { AppSettings.shared.securityDelay },
                    set: { AppSettings.shared.securityDelay = $0 }
                )) {
                    Text("立即").tag(0)
                    Text("30 秒").tag(30)
                    Text("1 分钟").tag(60)
                    Text("5 分钟").tag(300)
                    Text("15 分钟").tag(900)
                }
            }
        }
    }

    // MARK: - Advanced (对齐 Android Settings: 高级)

    private var advancedSection: some View {
        Section("高级") {
            // 历史记录容量 (对齐 Android Settings.KEY_HISTORY_INFO_SIZE)
            Stepper("历史记录上限: \(AppSettings.shared.historyInfoSize)", value: Binding(
                get: { AppSettings.shared.historyInfoSize },
                set: { AppSettings.shared.historyInfoSize = $0 }
            ), in: 100...2000, step: 100)

            // 保存解析错误 (对齐 Android Settings.KEY_SAVE_PARSE_ERROR_BODY)
            Toggle("保存解析错误", isOn: Binding(
                get: { AppSettings.shared.saveParseErrorBody },
                set: { AppSettings.shared.saveParseErrorBody = $0 }
            ))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }

            Button("源代码") {
                openURL(URL(string: "https://github.com/nicegram/EhViewer")!)
            }

            NavigationLink("开源协议") {
                licensesView
            }
        }
    }

    private var licensesView: some View {
        List {
            ForEach(["GRDB.swift", "SwiftSoup", "SDWebImageSwiftUI"], id: \.self) { name in
                Text(name)
                    .font(.subheadline)
            }
        }
        .navigationTitle("开源协议")
    }
}

// MARK: - ViewModel

@Observable
class SettingsViewModel {
    var isLoggedIn = false
    var hasExAccess = false
    var showLogoutConfirm = false
    var showLogin = false

    var gallerySite: Int {
        get { AppSettings.shared.gallerySite.rawValue }
        set { AppSettings.shared.gallerySite = EhSite(rawValue: newValue) ?? .eHentai }
    }
    var listMode: Int {
        get { AppSettings.shared.listMode.rawValue }
        set { AppSettings.shared.listMode = ListMode(rawValue: newValue) ?? .list }
    }
    var showJpnTitle: Bool {
        get { AppSettings.shared.showJpnTitle }
        set { AppSettings.shared.showJpnTitle = newValue }
    }
    var showTagTranslations: Bool {
        get { AppSettings.shared.showTagTranslations }
        set { AppSettings.shared.showTagTranslations = newValue }
    }
    
    // 标签数据库状态
    var isUpdatingTagDb = false
    var tagDbUpdateSuccess = false
    var tagDbStatus: String {
        let db = EhTagDatabase.shared
        if db.isLoaded {
            if let version = db.version {
                return "已加载 (\(version.prefix(10)))"
            }
            return "已加载"
        }
        return "未加载"
    }
    
    func updateTagDatabase() async {
        isUpdatingTagDb = true
        tagDbUpdateSuccess = false
        
        do {
            try await EhTagDatabase.shared.updateDatabase(forceUpdate: true)
            await MainActor.run {
                self.tagDbUpdateSuccess = true
                self.isUpdatingTagDb = false
            }
        } catch {
            print("[SettingsVM] Failed to update tag database: \(error)")
            await MainActor.run {
                self.isUpdatingTagDb = false
            }
        }
    }
    
    var domainFronting: Bool {
        get { AppSettings.shared.domainFronting }
        set { AppSettings.shared.domainFronting = newValue }
    }
    var dnsOverHttps: Bool {
        get { AppSettings.shared.dnsOverHttps }
        set { AppSettings.shared.dnsOverHttps = newValue }
    }
    var builtInHosts: Bool {
        get { AppSettings.shared.builtInHosts }
        set { AppSettings.shared.builtInHosts = newValue }
    }
    var preloadImage: Int {
        get { AppSettings.shared.preloadImage }
        set { AppSettings.shared.preloadImage = newValue }
    }
    var keepScreenOn: Bool {
        get { AppSettings.shared.keepScreenOn }
        set { AppSettings.shared.keepScreenOn = newValue }
    }
    var multiThread: Int {
        get { AppSettings.shared.multiThreadDownload }
        set { AppSettings.shared.multiThreadDownload = newValue }
    }
    var downloadTimeout: Int {
        get { AppSettings.shared.downloadTimeout }
        set { AppSettings.shared.downloadTimeout = newValue }
    }

    // 网络诊断状态
    var isDiagnosing = false
    var diagnosisResult = ""
    var diagnosisSuccess = false

    var diskCacheSize: String = "计算中..."

    func calculateCacheSize() {
        let urlCacheSize = URLCache.shared.currentDiskUsage
        let byteFormatter = ByteCountFormatter()
        byteFormatter.allowedUnits = [.useMB, .useGB]
        byteFormatter.countStyle = .file
        diskCacheSize = byteFormatter.string(fromByteCount: Int64(urlCacheSize))
    }

    func clearCache() {
        // 清除内存缓存
        GalleryCache.shared.clearAll()
        // 清除 URL 磁盘缓存
        URLCache.shared.removeAllCachedResponses()
        calculateCacheSize()
    }

    #if os(macOS)
    var downloadPath: String {
        if let path = UserDefaults.standard.string(forKey: "downloadPath"), !path.isEmpty {
            return path
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("download").path
    }

    func chooseDownloadPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择下载目录"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: "downloadPath")
        }
    }
    #endif

    init() {
        checkLoginState()
        calculateCacheSize()
    }

    func checkLoginState() {
        let ehCookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://e-hentai.org")!) ?? []
        isLoggedIn = ehCookies.contains { $0.name == "ipb_member_id" }

        let exCookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://exhentai.org")!) ?? []
        hasExAccess = exCookies.contains { $0.name == "igneous" && !$0.value.isEmpty && $0.value != "mystery" }
    }

    func logout() {
        // 清除所有 EH 相关 Cookie
        let storage = HTTPCookieStorage.shared
        for domain in ["e-hentai.org", "exhentai.org", ".e-hentai.org", ".exhentai.org"] {
            if let cookies = storage.cookies(for: URL(string: "https://\(domain)")!) {
                for cookie in cookies { storage.deleteCookie(cookie) }
            }
        }
        isLoggedIn = false
        hasExAccess = false
    }
    
    /// 网络诊断
    func runNetworkDiagnostics() {
        guard !isDiagnosing else { return }
        isDiagnosing = true
        diagnosisResult = ""
        diagnosisSuccess = false
        
        Task {
            var results: [String] = []
            var allSuccess = true
            
            // 1. DNS 解析测试
            let hosts = ["e-hentai.org", "exhentai.org"]
            for host in hosts {
                let hostRef = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
                var resolved = DarwinBoolean(false)
                CFHostStartInfoResolution(hostRef, .addresses, nil)
                if let addresses = CFHostGetAddressing(hostRef, &resolved)?.takeUnretainedValue() as? [Data], !addresses.isEmpty {
                    // 提取 IP 地址
                    if let addr = addresses.first {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        addr.withUnsafeBytes { ptr in
                            let sockaddr = ptr.bindMemory(to: sockaddr.self).baseAddress!
                            getnameinfo(sockaddr, socklen_t(addr.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                        }
                        let ip = String(cString: hostname)
                        results.append("✓ \(host) → \(ip)")
                    }
                } else {
                    results.append("✗ \(host) DNS 解析失败")
                    allSuccess = false
                }
            }
            
            // 2. HTTPS 连接测试
            for host in hosts {
                let url = URL(string: "https://\(host)/")!
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                request.httpMethod = "HEAD"
                
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                            results.append("✓ \(host) HTTPS 连接正常")
                        } else {
                            results.append("⚠ \(host) HTTP \(httpResponse.statusCode)")
                        }
                    }
                } catch let error as NSError {
                    if error.domain == NSURLErrorDomain {
                        switch error.code {
                        case NSURLErrorTimedOut:
                            results.append("✗ \(host) 连接超时")
                        case NSURLErrorCannotConnectToHost:
                            results.append("✗ \(host) 无法连接")
                        case NSURLErrorSecureConnectionFailed:
                            results.append("✗ \(host) TLS 错误 (可能被阻断)")
                        case NSURLErrorServerCertificateUntrusted:
                            results.append("✗ \(host) 证书不受信任")
                        default:
                            results.append("✗ \(host) 错误: \(error.localizedDescription)")
                        }
                    } else {
                        results.append("✗ \(host) 错误: \(error.localizedDescription)")
                    }
                    allSuccess = false
                }
            }
            
            // 3. 代理检测
            #if os(iOS)
            let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
            if let httpProxy = proxySettings?["HTTPProxy"] as? String, !httpProxy.isEmpty {
                results.append("ℹ 检测到 HTTP 代理: \(httpProxy)")
            }
            #endif
            
            await MainActor.run {
                self.diagnosisResult = results.joined(separator: "\n")
                self.diagnosisSuccess = allSuccess
                self.isDiagnosing = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
