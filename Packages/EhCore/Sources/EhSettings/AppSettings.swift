import Foundation

// MARK: - 全局设置系统 (对应 Android Settings.java)

@Observable
public final class AppSettings: @unchecked Sendable {
    public static let shared = AppSettings()

    // MARK: - 站点选择
    @ObservationIgnored
    public var gallerySite: EhSite {
        get { EhSite(rawValue: UserDefaults.standard.integer(forKey: "gallery_site")) ?? .eHentai }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "gallery_site") }
    }

    // MARK: - 网络
    // 注意: Domain Fronting 在 iOS/macOS 的 URLSession 中无法正确工作
    // (URL 域名替换为 IP 会破坏 TLS SNI，导致 Cloudflare 返回错误证书)
    // Android OkHttp 的 Dns 接口在 socket 层替换 IP 不影响 TLS，但 URLSession 无此机制
    // 因此该选项默认关闭，依赖系统 DNS / 代理 / VPN 解析域名
    @ObservationIgnored
    public var domainFronting: Bool {
        get { UserDefaults.standard.object(forKey: "domain_fronting") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "domain_fronting") }
    }

    @ObservationIgnored
    public var dnsOverHttps: Bool {
        get { UserDefaults.standard.bool(forKey: "dns_over_https") }
        set { UserDefaults.standard.set(newValue, forKey: "dns_over_https") }
    }

    @ObservationIgnored
    public var builtInHosts: Bool {
        get { UserDefaults.standard.object(forKey: "built_in_hosts") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "built_in_hosts") }
    }

    // MARK: - 下载
    @ObservationIgnored
    public var multiThreadDownload: Int {
        get { max(1, min(10, UserDefaults.standard.integer(forKey: "multi_thread_download"))) }
        set { UserDefaults.standard.set(max(1, min(10, newValue)), forKey: "multi_thread_download") }
    }

    @ObservationIgnored
    public var preloadImage: Int {
        get { UserDefaults.standard.object(forKey: "preload_image") as? Int ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "preload_image") }
    }

    @ObservationIgnored
    public var downloadDelay: Int {
        get { UserDefaults.standard.integer(forKey: "download_delay") }
        set { UserDefaults.standard.set(newValue, forKey: "download_delay") }
    }

    @ObservationIgnored
    public var downloadTimeout: Int {
        get { UserDefaults.standard.object(forKey: "download_timeout") as? Int ?? 60 }
        set { UserDefaults.standard.set(newValue, forKey: "download_timeout") }
    }

    @ObservationIgnored
    public var downloadOriginImage: Bool {
        get { UserDefaults.standard.bool(forKey: "download_origin_image") }
        set { UserDefaults.standard.set(newValue, forKey: "download_origin_image") }
    }

    /// 图片分辨率 (对应 Android EhConfig.IMAGE_SIZE_*)
    /// "a" = 自动, "780", "980", "1280", "1600", "2400"
    @ObservationIgnored
    public var imageResolution: ImageResolution {
        get {
            let raw = UserDefaults.standard.string(forKey: "image_resolution") ?? "a"
            return ImageResolution(rawValue: raw) ?? .auto
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "image_resolution") }
    }

    // MARK: - 缓存
    @ObservationIgnored
    public var readCacheSize: Int {
        get {
            let v = UserDefaults.standard.object(forKey: "read_cache_size") as? Int ?? 320
            return max(40, min(640, v))
        }
        set { UserDefaults.standard.set(max(40, min(640, newValue)), forKey: "read_cache_size") }
    }

    // MARK: - 外观
    @ObservationIgnored
    public var listMode: ListMode {
        get { ListMode(rawValue: UserDefaults.standard.integer(forKey: "list_mode")) ?? .list }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "list_mode") }
    }

    @ObservationIgnored
    public var showJpnTitle: Bool {
        get { UserDefaults.standard.bool(forKey: "show_jpn_title") }
        set { UserDefaults.standard.set(newValue, forKey: "show_jpn_title") }
    }

    // MARK: - 用户身份
    @ObservationIgnored
    public var isLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "is_login") }
        set { UserDefaults.standard.set(newValue, forKey: "is_login") }
    }

    @ObservationIgnored
    public var displayName: String? {
        get { UserDefaults.standard.string(forKey: "display_name") }
        set { UserDefaults.standard.set(newValue, forKey: "display_name") }
    }

    @ObservationIgnored
    public var userId: String? {
        get { UserDefaults.standard.string(forKey: "user_id") }
        set { UserDefaults.standard.set(newValue, forKey: "user_id") }
    }

    @ObservationIgnored
    public var avatar: String? {
        get { UserDefaults.standard.string(forKey: "avatar") }
        set { UserDefaults.standard.set(newValue, forKey: "avatar") }
    }

    // MARK: - 外观
    @ObservationIgnored
    public var theme: Int {
        get { UserDefaults.standard.integer(forKey: "theme") }
        set { UserDefaults.standard.set(newValue, forKey: "theme") }
    }

    @ObservationIgnored
    public var launchPage: Int {
        get { UserDefaults.standard.integer(forKey: "launch_page") }
        set { UserDefaults.standard.set(newValue, forKey: "launch_page") }
    }

    @ObservationIgnored
    public var thumbSize: Int {
        get { UserDefaults.standard.object(forKey: "thumb_size") as? Int ?? 1 }
        set { UserDefaults.standard.set(newValue, forKey: "thumb_size") }
    }

    @ObservationIgnored
    public var showGalleryPages: Bool {
        get { UserDefaults.standard.bool(forKey: "show_gallery_pages") }
        set { UserDefaults.standard.set(newValue, forKey: "show_gallery_pages") }
    }

    @ObservationIgnored
    public var showTagTranslations: Bool {
        get { UserDefaults.standard.object(forKey: "show_tag_translations") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_tag_translations") }
    }

    @ObservationIgnored
    public var showGalleryComment: Bool {
        get { UserDefaults.standard.object(forKey: "show_gallery_comment") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_gallery_comment") }
    }

    @ObservationIgnored
    public var showGalleryRating: Bool {
        get { UserDefaults.standard.object(forKey: "show_gallery_rating") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_gallery_rating") }
    }

    @ObservationIgnored
    public var showReadProgress: Bool {
        get { UserDefaults.standard.object(forKey: "show_read_progress") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_read_progress") }
    }

    /// 大屏幕列表布局模式 (对齐 Android: 0=自适应双栏, 1=全宽单列表)
    @ObservationIgnored
    public var wideScreenListMode: Int {
        get { UserDefaults.standard.integer(forKey: "wide_screen_list_mode") }
        set { UserDefaults.standard.set(newValue, forKey: "wide_screen_list_mode") }
    }

    @ObservationIgnored
    public var showEhEvents: Bool {
        get { UserDefaults.standard.object(forKey: "show_eh_events") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_eh_events") }
    }

    @ObservationIgnored
    public var showEhLimits: Bool {
        get { UserDefaults.standard.object(forKey: "show_eh_limits") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_eh_limits") }
    }

    // MARK: - 过滤 / 搜索
    @ObservationIgnored
    public var defaultCategories: Int {
        get { UserDefaults.standard.object(forKey: "default_categories") as? Int ?? 0x3FF }
        set { UserDefaults.standard.set(newValue, forKey: "default_categories") }
    }

    @ObservationIgnored
    public var excludedTagNamespaces: Int {
        get { UserDefaults.standard.integer(forKey: "excluded_tag_namespaces") }
        set { UserDefaults.standard.set(newValue, forKey: "excluded_tag_namespaces") }
    }

    @ObservationIgnored
    public var excludedLanguages: String? {
        get { UserDefaults.standard.string(forKey: "excluded_languages") }
        set { UserDefaults.standard.set(newValue, forKey: "excluded_languages") }
    }

    @ObservationIgnored
    public var cellularNetworkWarning: Bool {
        get { UserDefaults.standard.bool(forKey: "cellular_network_warning") }
        set { UserDefaults.standard.set(newValue, forKey: "cellular_network_warning") }
    }

    // MARK: - 阅读器
    @ObservationIgnored
    public var readingDirection: Int {
        get { UserDefaults.standard.object(forKey: "reading_direction") as? Int ?? 1 }
        set { UserDefaults.standard.set(newValue, forKey: "reading_direction") }
    }

    @ObservationIgnored
    public var pageScaling: Int {
        get { UserDefaults.standard.object(forKey: "page_scaling") as? Int ?? 3 }
        set { UserDefaults.standard.set(newValue, forKey: "page_scaling") }
    }

    @ObservationIgnored
    public var startPosition: Int {
        get { UserDefaults.standard.integer(forKey: "start_position") }
        set { UserDefaults.standard.set(newValue, forKey: "start_position") }
    }

    @ObservationIgnored
    public var keepScreenOn: Bool {
        get { UserDefaults.standard.bool(forKey: "keep_screen_on") }
        set { UserDefaults.standard.set(newValue, forKey: "keep_screen_on") }
    }

    @ObservationIgnored
    public var readingFullscreen: Bool {
        get { UserDefaults.standard.object(forKey: "reading_fullscreen") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "reading_fullscreen") }
    }

    @ObservationIgnored
    public var showClock: Bool {
        get { UserDefaults.standard.object(forKey: "gallery_show_clock") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "gallery_show_clock") }
    }

    @ObservationIgnored
    public var showProgress: Bool {
        get { UserDefaults.standard.object(forKey: "gallery_show_progress") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "gallery_show_progress") }
    }

    @ObservationIgnored
    public var showBattery: Bool {
        get { UserDefaults.standard.object(forKey: "gallery_show_battery") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "gallery_show_battery") }
    }

    @ObservationIgnored
    public var customScreenLightness: Bool {
        get { UserDefaults.standard.bool(forKey: "custom_screen_lightness") }
        set { UserDefaults.standard.set(newValue, forKey: "custom_screen_lightness") }
    }

    @ObservationIgnored
    public var screenLightness: Int {
        get { UserDefaults.standard.object(forKey: "screen_lightness") as? Int ?? 50 }
        set { UserDefaults.standard.set(newValue, forKey: "screen_lightness") }
    }

    // MARK: - 阅读器 (新增)

    /// 音量键翻页
    @ObservationIgnored
    public var volumePage: Bool {
        get { UserDefaults.standard.bool(forKey: "volume_page") }
        set { UserDefaults.standard.set(newValue, forKey: "volume_page") }
    }

    /// 反转音量键
    @ObservationIgnored
    public var reverseVolumePage: Bool {
        get { UserDefaults.standard.bool(forKey: "reverse_volume_page") }
        set { UserDefaults.standard.set(newValue, forKey: "reverse_volume_page") }
    }

    /// 显示页面间距
    @ObservationIgnored
    public var showPageInterval: Bool {
        get { UserDefaults.standard.bool(forKey: "show_page_interval") }
        set { UserDefaults.standard.set(newValue, forKey: "show_page_interval") }
    }

    /// 屏幕旋转 (0=跟随系统, 1=竖屏, 2=横屏)
    @ObservationIgnored
    public var screenRotation: Int {
        get { UserDefaults.standard.integer(forKey: "screen_rotation") }
        set { UserDefaults.standard.set(newValue, forKey: "screen_rotation") }
    }

    /// 自动翻页延迟 (秒)
    @ObservationIgnored
    public var autoPageInterval: Int {
        get { UserDefaults.standard.object(forKey: "auto_page_interval") as? Int ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "auto_page_interval") }
    }

    /// 色彩滤镜 (护眼模式)
    @ObservationIgnored
    public var colorFilter: Bool {
        get { UserDefaults.standard.bool(forKey: "color_filter") }
        set { UserDefaults.standard.set(newValue, forKey: "color_filter") }
    }

    /// 色彩滤镜颜色
    @ObservationIgnored
    public var colorFilterColor: Int {
        get { UserDefaults.standard.object(forKey: "color_filter_color") as? Int ?? 0x20000000 }
        set { UserDefaults.standard.set(newValue, forKey: "color_filter_color") }
    }

    // MARK: - 收藏
    @ObservationIgnored
    public var recentFavCat: Int {
        get { UserDefaults.standard.object(forKey: "recent_fav_cat") as? Int ?? -1 }
        set { UserDefaults.standard.set(newValue, forKey: "recent_fav_cat") }
    }

    @ObservationIgnored
    public var defaultFavSlot: Int {
        get { UserDefaults.standard.object(forKey: "default_favorite_2") as? Int ?? -2 }
        set { UserDefaults.standard.set(newValue, forKey: "default_favorite_2") }
    }

    /// 收藏夹名称 (0-9)
    public func favCatName(_ index: Int) -> String {
        UserDefaults.standard.string(forKey: "fav_cat_\(index)") ?? "Favorites \(index)"
    }

    public func setFavCatName(_ index: Int, _ name: String) {
        UserDefaults.standard.set(name, forKey: "fav_cat_\(index)")
    }

    /// 收藏夹计数 (0-9)
    public func favCount(_ index: Int) -> Int {
        UserDefaults.standard.integer(forKey: "fav_count_\(index)")
    }

    public func setFavCount(_ index: Int, _ count: Int) {
        UserDefaults.standard.set(count, forKey: "fav_count_\(index)")
    }

    // MARK: - 下载
    @ObservationIgnored
    public var recentDownloadLabel: String? {
        get { UserDefaults.standard.string(forKey: "recent_download_label") }
        set { UserDefaults.standard.set(newValue, forKey: "recent_download_label") }
    }

    @ObservationIgnored
    public var hasDefaultDownloadLabel: Bool {
        get { UserDefaults.standard.bool(forKey: "has_default_download_label") }
        set { UserDefaults.standard.set(newValue, forKey: "has_default_download_label") }
    }

    @ObservationIgnored
    public var defaultDownloadLabel: String? {
        get { UserDefaults.standard.string(forKey: "default_download_label") }
        set { UserDefaults.standard.set(newValue, forKey: "default_download_label") }
    }

    // MARK: - 首次启动引导
    
    /// 是否需要显示 18+ 警告 (首次启动时显示)
    @ObservationIgnored
    public var showWarning: Bool {
        get { UserDefaults.standard.object(forKey: "show_warning") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "show_warning") }
    }
    
    /// 是否已选择站点 (首次启动引导)
    @ObservationIgnored
    public var hasSelectedSite: Bool {
        get { UserDefaults.standard.bool(forKey: "has_selected_site") }
        set { UserDefaults.standard.set(newValue, forKey: "has_selected_site") }
    }

    /// 是否跳过登录 (游客模式，仅能访问 E-Hentai)
    /// 对应 Android: Settings.putNeedSignIn(false)
    @ObservationIgnored
    public var skipSignIn: Bool {
        get { UserDefaults.standard.bool(forKey: "skip_sign_in") }
        set { UserDefaults.standard.set(newValue, forKey: "skip_sign_in") }
    }

    // MARK: - 隐私安全
    @ObservationIgnored
    public var enableSecurity: Bool {
        get { UserDefaults.standard.bool(forKey: "enable_secure") }
        set { UserDefaults.standard.set(newValue, forKey: "enable_secure") }
    }
    
    /// 安全延迟时间 (秒) - 应用进入后台后多久需要重新认证
    @ObservationIgnored
    public var securityDelay: Int {
        get { UserDefaults.standard.object(forKey: "security_delay") as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: "security_delay") }
    }

    // MARK: - 高级
    @ObservationIgnored
    public var saveParseErrorBody: Bool {
        get { UserDefaults.standard.bool(forKey: "save_parse_error_body") }
        set { UserDefaults.standard.set(newValue, forKey: "save_parse_error_body") }
    }

    @ObservationIgnored
    public var historyInfoSize: Int {
        get { max(100, UserDefaults.standard.object(forKey: "history_info_size") as? Int ?? 100) }
        set { UserDefaults.standard.set(max(100, newValue), forKey: "history_info_size") }
    }

    // MARK: - Android 对齐: 附加设置

    /// 详情页信息大小 (对齐 Android Settings.KEY_DETAIL_SIZE; 0=normal, 1=large)
    @ObservationIgnored
    public var detailSize: Int {
        get { UserDefaults.standard.integer(forKey: "detail_size") }
        set { UserDefaults.standard.set(newValue, forKey: "detail_size") }
    }

    /// 缩略图分辨率 (对齐 Android Settings.KEY_THUMB_RESOLUTION; 0=normal, 1=large)
    @ObservationIgnored
    public var thumbResolution: Int {
        get { UserDefaults.standard.integer(forKey: "thumb_resolution") }
        set { UserDefaults.standard.set(newValue, forKey: "thumb_resolution") }
    }

    /// 修复缩略图链接 (对齐 Android Settings.KEY_FIX_THUMB_URL)
    @ObservationIgnored
    public var fixThumbUrl: Bool {
        get { UserDefaults.standard.bool(forKey: "fix_thumb_url") }
        set { UserDefaults.standard.set(newValue, forKey: "fix_thumb_url") }
    }

    /// 内置 ExHentai Hosts (对齐 Android Settings.KEY_BUILT_IN_HOSTS_EX)
    @ObservationIgnored
    public var builtExHosts: Bool {
        get { UserDefaults.standard.object(forKey: "built_ex_hosts") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "built_ex_hosts") }
    }

    /// 媒体扫描 (对齐 Android Settings.KEY_MEDIA_SCAN)
    @ObservationIgnored
    public var mediaScan: Bool {
        get { UserDefaults.standard.bool(forKey: "media_scan") }
        set { UserDefaults.standard.set(newValue, forKey: "media_scan") }
    }

    /// 导航栏主题色 (对齐 Android Settings.KEY_APPLY_NAV_BAR_THEME_COLOR)
    @ObservationIgnored
    public var applyNavBarThemeColor: Bool {
        get { UserDefaults.standard.bool(forKey: "apply_nav_bar_theme_color") }
        set { UserDefaults.standard.set(newValue, forKey: "apply_nav_bar_theme_color") }
    }

    private init() {
        // 注册默认值
        UserDefaults.standard.register(defaults: [
            "gallery_site": EhSite.eHentai.rawValue,
            "domain_fronting": false,   // iOS URLSession 域名前置不可靠，默认禁用
            "built_in_hosts": false,    // iOS URLSession 域名前置不可靠，默认禁用
            "multi_thread_download": 3,
            "preload_image": 5,
            "download_timeout": 60,
            "read_cache_size": 320,
            // 新增默认值
            "show_tag_translations": true,
            "show_gallery_comment": true,
            "show_gallery_rating": true,
            "show_read_progress": true,
            "show_eh_events": true,
            "show_eh_limits": true,
            "default_categories": 0x3FF,
            "reading_direction": 1,    // RTL
            "page_scaling": 3,         // FIT
            "reading_fullscreen": true,
            "gallery_show_clock": true,
            "gallery_show_progress": true,
            "gallery_show_battery": true,
            "screen_lightness": 50,
            "recent_fav_cat": -1,
            "default_favorite_2": -2,
            "thumb_size": 1,
            "image_size": "auto",
            "history_info_size": 100,
        ])
    }
}

public enum ListMode: Int, Sendable, CaseIterable {
    case list = 0
    case grid = 1
}

/// 图片分辨率选项 (对应 Android EhConfig.IMAGE_SIZE_*)
public enum ImageResolution: String, Sendable, CaseIterable, Identifiable {
    case auto = "a"      // 自动
    case x780 = "780"    // 780px
    case x980 = "980"    // 980px
    case x1280 = "1280"  // 1280px
    case x1600 = "1600"  // 1600px
    case x2400 = "2400"  // 2400px

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: return "自动"
        case .x780: return "780x"
        case .x980: return "980x"
        case .x1280: return "1280x"
        case .x1600: return "1600x"
        case .x2400: return "2400x"
        }
    }
}
