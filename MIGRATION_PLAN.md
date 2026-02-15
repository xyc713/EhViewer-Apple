# EhViewer → iPadOS (SwiftUI) 完整迁移规划书

> 基于对 Android 源码 2764 个文件的全量深度逆向分析  
> 生成日期：2026-02-12

---

## 目录

1. [项目全貌与核心发现](#1-项目全貌与核心发现)
2. [架构层次拆解](#2-架构层次拆解)
3. [核心机密逻辑清单](#3-核心机密逻辑清单)
4. [模块化任务清单](#4-模块化任务清单)
5. [Android → iOS 差异预警](#5-android--ios-差异预警)
6. [iPadOS 特化设计建议](#6-ipados-特化设计建议)
7. [技术选型推荐](#7-技术选型推荐)
8. [开发阶段排期](#8-开发阶段排期)

---

## 1. 项目全貌与核心发现

### 1.1 这是什么 App

EhViewer 是一个 **E-Hentai / ExHentai 画廊浏览客户端**，核心功能包括：

| 功能 | 说明 |
|------|------|
| 双站点浏览 | E-Hentai（表站）+ ExHentai（里站）无缝切换 |
| 画廊搜索 | 关键词、标签、上传者、以图搜图、高级过滤 |
| 在线阅读 | 多线程预取 + OpenGL 渲染的高性能图片查看器 |
| 离线下载 | 断点续传 + 下载队列 + 标签分组管理 |
| 收藏管理 | 10 组远程收藏 + 本地收藏 + 订阅 |
| 排行榜 | 7 类排行，每类 4 个时间维度 |
| 评论互动 | 发评论、编辑、投票 |
| 种子/归档 | 种子下载、服务器端压缩包下载 |
| 域前置/DoH | 中国大陆访问的反审查网络层 |

### 1.2 代码规模

| 指标 | 数量 |
|------|------|
| Java 源文件 | ~200+ |
| Kotlin 源文件 | ~30+ |
| HTML 解析器 | 21 个 Parser |
| API 端点 | 30+ 个 |
| 数据库表 | 10 张 |
| UI 页面 (Scene) | 20+ 个 |
| Native C 代码 | 图片解码 + 7z 解压 |

### 1.3 最关键的发现

> **无加密、无签名、无自定义协议。** 所有图片以原始格式传输和存储。App 的核心价值在于：
> 1. **精准的 HTML 解析器集合**（21 个，大量正则 + Jsoup 双路径解析）
> 2. **高效的多线程图片抓取引擎** (SpiderQueen)
> 3. **完善的 Cookie/Session 管理**（登录态维持 + Sad Panda 检测）
> 4. **域前置 (Domain Fronting)** 网络对抗能力

---

## 2. 架构层次拆解

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  Scene 系统 (Fragment-based)                     │
│  ┌──────────┬──────────┬──────────┬───────────┐ │
│  │GalleryList│GalleryDet│Favorites │ Downloads │ │
│  │  Scene   │ ailScene │  Scene   │   Scene   │ │
│  └──────────┴──────────┴──────────┴───────────┘ │
│  GalleryActivity (OpenGL 全屏阅读器)             │
├─────────────────────────────────────────────────┤
│                ViewModel / 中间层                │
│  ┌──────────┬──────────┬──────────┐             │
│  │EhClient  │Download  │Favourite │             │
│  │(AsyncTask)│Manager  │StatusRtr │             │
│  └──────────┴──────────┴──────────┘             │
├─────────────────────────────────────────────────┤
│                Network Layer                     │
│  ┌──────────────────────────────────────┐       │
│  │         EhEngine (30 个 API 方法)     │       │
│  │  ┌─────────┐  ┌─────────┐           │       │
│  │  │OkHttp   │  │OkHttp   │           │       │
│  │  │(通用)    │  │(图片)    │           │       │
│  │  └─────────┘  └─────────┘           │       │
│  │  EhCookieStore + EhSSLSocketFactory  │       │
│  │  EhHosts + EhProxySelector + DoH     │       │
│  └──────────────────────────────────────┘       │
├─────────────────────────────────────────────────┤
│                Parser Layer                      │
│  21 个 HTML/JSON 解析器                          │
│  (Jsoup + Regex + org.json)                     │
├─────────────────────────────────────────────────┤
│                Spider Engine                     │
│  ┌────────────────────────────────────┐         │
│  │ SpiderQueen (QueenThread + Workers)│         │
│  │ SpiderDen (磁盘缓存 + 下载目录)    │         │
│  │ SpiderInfo (.ehviewer 元数据文件)   │         │
│  └────────────────────────────────────┘         │
├─────────────────────────────────────────────────┤
│                Data Layer                        │
│  GreenDAO (SQLite) → 10 张表                     │
│  SharedPreferences → 100+ 设置项                 │
│  SimpleDiskCache → 缩略图/SpiderInfo/HTTP        │
├─────────────────────────────────────────────────┤
│                Native Layer                      │
│  image.c (图片解码) + 7zip (归档解压)            │
│  gif/ (GIF 解码)                                │
└─────────────────────────────────────────────────┘
```

---

## 3. 核心机密逻辑清单

以下是迁移时 **必须精准复刻** 的逻辑，否则 App 无法工作：

### 3.1 登录与 Cookie 机制

| 机制 | 详情 |
|------|------|
| **登录方式** | POST 到 `forums.e-hentai.org/index.php?act=Login&CODE=01`，表单字段：`UserName`, `PassWord`, `CookieDate=1` |
| **核心 Cookie** | `ipb_member_id` + `ipb_pass_hash`（E 站登录凭证），`igneous`（EX 站访问令牌） |
| **登录判定** | 检查 E 站域名下同时存在 `ipb_member_id` 和 `ipb_pass_hash` |
| **nw Cookie** | 硬编码注入 `nw=1`（跳过内容警告），永不过期 |
| **uconfig Cookie** | 序列化格式：`uh_y-xr_a-rx_0-...`，键值对以 `-` 分隔，键与值以 `_` 分隔 |
| **Sad Panda 检测** | 响应头含 `filename="sadpanda.jpg"` 或 body 含 `kokomade.jpg` → 登录失效 |
| **Cookie 域迁移** | 支持在 E 站和 EX 站间同步 Cookie，强制持久化 |

### 3.2 请求构建规范

| 项目 | 值 |
|------|------|
| **User-Agent** | `Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36` |
| **Accept** | `image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8` |
| **Accept-Language** | `zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7` |
| **Referer / Origin** | 根据当前站点动态生成 |
| **JSON API content-type** | `application/json; charset=utf-8` |

### 3.3 JSON API 协议（发送到 `api.php`）

| method | 用途 | 请求体 |
|--------|------|--------|
| `gdata` | 批量画廊元数据 | `{"method":"gdata","gidlist":[[gid,token],...],"namespace":1}` |
| `rategallery` | 评分 | `{"method":"rategallery","apiuid":..,"apikey":"..","gid":..,"token":"..","rating":ceil(r*2)}` |
| `gtoken` | 获取页 token | `{"method":"gtoken","pagelist":[[gid,gtoken,page+1]]}` |
| `votecomment` | 评论投票 | `{"method":"votecomment","apiuid":..,"apikey":"..","gid":..,"token":"..","comment_id":..,"comment_vote":..}` |
| `showpage` | 图片页信息 | `{"method":"showpage","gid":..,"page":index+1,"imgkey":"..","showkey":".."}` |

### 3.4 画廊评分算法

```
// 从 CSS background-position 的两个像素值推导评分
rate = 5 - num1/16
if (num2 == 21) → rate -= 1, rate += 0.5 (半星)
```

### 3.5 收藏夹色彩识别

通过 `rgba(r,g,b,` 颜色映射到收藏夹编号 0-9：
```
0:(0,0,0)  1:(240,0,0)  2:(240,160,0)  3:(208,208,0)  4:(0,128,0)
5:(144,240,64)  6:(64,176,240)  7:(0,0,240)  8:(80,0,128)  9:(224,128,224)
```

### 3.6 URL 深链解析正则

| URL 类型 | 正则 |
|----------|------|
| 画廊详情 | `https?://(?:exhentai\.org\|e-hentai\.org\|lofi\.e-hentai\.org)/(?:g\|mpv)/(\d+)/([0-9a-f]{10})` |
| 画廊页面 | `https?://(?:exhentai\.org\|e-hentai\.org\|lofi\.e-hentai\.org)/s/([0-9a-f]{10})/(\d+)-(\d+)` |

### 3.7 图片抓取管线 (SpiderQueen)

```
1. 获取 pToken (从 SpiderInfo 缓存 或 请求预览页)
2. 构建页面 URL: {host}s/{pToken}/{gid}-{index+1}
3. 第一次: GET HTML → 解析得 imageUrl + showKey + skipHathKey
4. 后续: POST api.php (showpage) → 解析得 imageUrl
5. 下载图片 → 反劫持校验 (对比请求/响应 URL)
6. 纯文本检测 (所有字节 ≤126 → 判定非图片)
7. 509 检测 (URL 以 /509.gif 结尾 → 限流)
8. 5 次重试，失败后走 HTML 路径重新获取
```

### 3.8 SpiderInfo 文件格式 (.ehviewer)

```
VERSION2              ← 版本标识
00000000              ← startPage (hex)
1234567               ← gid
abcdef1234            ← token
1                     ← deprecated mode
42                    ← previewPages
20                    ← previewPerPage
500                   ← pages
0 abc123def           ← index pToken (逐行)
1 def456abc
...
```

### 3.9 域前置 (Domain Fronting)

SSL 握手时使用 IP 地址而非域名（绕过 SNI 封锁）：
- 关闭原 socket → 用 InetAddress 创建新 SSL socket
- 配合内置 Hosts 使用

---

## 4. 模块化任务清单

### Phase 0: 项目基建 [优先级: P0]

| # | 任务 | 估时 | 说明 |
|---|------|------|------|
| 0.1 | 创建 Xcode 项目 + SwiftUI 基础架构 | 0.5d | SPM 包管理，Target 配置 iPadOS 16+ |
| 0.2 | 设计 Swift Package 分层 | 0.5d | `EhCore` / `EhNetwork` / `EhParser` / `EhUI` |
| 0.3 | 配置 CI/CD 基础 | 0.5d | Fastlane + TestFlight |

### Phase 1: 数据模型层 (Model) [优先级: P0]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 1.1 | `GalleryInfo` 模型 | GalleryInfo.java | Swift struct, Codable | 0.5d |
| 1.2 | `GalleryDetail` 模型 | GalleryDetail.java | Swift struct, 扩展 GalleryInfo | 0.5d |
| 1.3 | `GalleryComment` 模型 | GalleryComment.java | Swift struct | 0.25d |
| 1.4 | `GalleryTagGroup` 模型 | GalleryTagGroup.java | Swift struct | 0.25d |
| 1.5 | `PreviewSet` 模型 | PreviewSet/Normal/Large | Swift enum + associated values | 0.5d |
| 1.6 | `DownloadInfo` 模型 | DownloadInfo.java | Swift struct + SwiftData @Model | 0.5d |
| 1.7 | `ListUrlBuilder` | ListUrlBuilder.java | Swift struct, 8 种 mode enum | 1d |
| 1.8 | `FavListUrlBuilder` | FavListUrlBuilder.java | Swift struct | 0.25d |
| 1.9 | `EhConfig` (uconfig 序列化) | EhConfig.java | Swift struct + 自定义编码 | 0.5d |
| 1.10 | `SpiderInfo` (文件格式读写) | SpiderInfo.java | Swift struct + 自定义 Parser | 0.5d |
| 1.11 | 其他小模型 | ArchiverData, HomeDetail 等 | Swift struct | 0.5d |

### Phase 2: 数据库层 (Persistence) [优先级: P0]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 2.1 | 数据库 Schema 设计 | EhDB.java (10 表) | SwiftData 或 GRDB | 1d |
| 2.2 | Downloads 仓储 | DownloadsDao | Repository pattern | 0.5d |
| 2.3 | LocalFavorites 仓储 | LocalFavoritesDao | Repository pattern | 0.5d |
| 2.4 | History 仓储 | HistoryDao | Repository pattern | 0.5d |
| 2.5 | QuickSearch 仓储 | QuickSearchDao | Repository pattern | 0.25d |
| 2.6 | Filter / BlackList 仓储 | FilterDao / BlackListDao | Repository pattern | 0.5d |
| 2.7 | DownloadDirname 映射 | DownloadDirnameDao | Repository pattern | 0.25d |
| 2.8 | 导入/导出功能 | EhDB.exportDB/importDB | 文件系统操作 | 1d |
| 2.9 | Settings 系统 | Settings.java (100+ 项) | @AppStorage + UserDefaults | 1d |

### Phase 3: 网络层 (Network) [优先级: P0]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 3.1 | HTTP 客户端配置 | EhApplication (OkHttp) | URLSession 配置 (2 个) | 1d |
| 3.2 | Cookie 管理器 | EhCookieStore + CookieRepository | HTTPCookieStorage + 自定义 | 1.5d |
| 3.3 | 请求构建器 | EhRequestBuilder | URLRequest 扩展 + 统一 Header | 0.5d |
| 3.4 | URL 常量系统 | EhUrl.java | Swift enum EhURL | 0.5d |
| 3.5 | SSL/域前置 | EhSSLSocketFactory | URLSessionDelegate + 自定义 TLS | 2d |
| 3.6 | 自定义 DNS (DoH) | EhHosts.kt | 自定义 DNS resolver | 1d |
| 3.7 | 代理选择器 | EhProxySelector.java | URLSessionConfiguration.proxy | 0.5d |
| 3.8 | Sad Panda / 509 检测 | EhEngine 内嵌逻辑 | 全局 Response 拦截器 | 0.5d |

### Phase 4: API 引擎层 (EhEngine) [优先级: P0]

| # | 任务 | Android 方法 | 估时 |
|---|------|-------------|------|
| 4.1 | signIn() | 论坛登录 POST | 0.5d |
| 4.2 | getGalleryList() | 画廊列表 GET + fillByApi | 1d |
| 4.3 | getGalleryDetail() | 画廊详情 GET | 0.5d |
| 4.4 | rateGallery() | 评分 POST JSON | 0.25d |
| 4.5 | commentGallery() | 评论 POST Form | 0.25d |
| 4.6 | getFavorites() + addFavorites() + modifyFavorites() | 收藏操作 | 1d |
| 4.7 | getGalleryPage() + getGalleryPageApi() | 图片页获取 | 0.5d |
| 4.8 | getGalleryToken() | Token API | 0.25d |
| 4.9 | imageSearch() | 以图搜图 Multipart | 0.5d |
| 4.10 | getTorrentList() + getArchiveList() | 种子/归档 | 0.5d |
| 4.11 | downloadArchive() + downloadArchiver() | 归档下载（二次请求） | 1d |
| 4.12 | getProfile() | 用户资料（二步请求） | 0.25d |
| 4.13 | voteComment() | 评论投票 | 0.25d |
| 4.14 | getTopList() | 排行榜 | 0.25d |
| 4.15 | getHomeDetail() + resetLimit() | 配额查询重置 | 0.25d |
| 4.16 | 统一错误处理 (doThrowException) | 全局 try-catch 模式 | 0.5d |
| 4.17 | getWatchedList / addTag / deleteWatchedTag | 标签订阅管理 | 0.5d |

### Phase 5: 解析器层 (Parser) [优先级: P0 — 最核心]

| # | 任务 | Android 文件 | 复杂度 | 估时 |
|---|------|-------------|--------|------|
| 5.1 | ParserUtils | ParserUtils.java | 低 | 0.25d |
| 5.2 | **GalleryListParser** | GalleryListParser.java | **极高** | 2d |
| 5.3 | **GalleryDetailParser** | GalleryDetailParser.java (799行) | **极高** | 3d |
| 5.4 | GalleryPageParser | GalleryPageParser.java | 中 | 0.5d |
| 5.5 | GalleryPageApiParser | GalleryPageApiParser.java | 中 | 0.5d |
| 5.6 | GalleryApiParser | GalleryApiParser.java | 中 | 0.5d |
| 5.7 | SignInParser | SignInParser.java | 低 | 0.25d |
| 5.8 | FavoritesParser | FavoritesParser.java | 高 | 1d |
| 5.9 | URL Parsers (3个) | DetailUrl/PageUrl/ListUrl Parser | 中 | 0.5d |
| 5.10 | GalleryTokenApiParser | GalleryTokenApiParser.java | 低 | 0.25d |
| 5.11 | TopListParser | TopListParser.java | 高 | 1d |
| 5.12 | TorrentParser | TorrentParser.java | 低 | 0.25d |
| 5.13 | ArchiveParser | ArchiveParser.java | 高 | 1d |
| 5.14 | RateGalleryParser | RateGalleryParser.java | 低 | 0.1d |
| 5.15 | VoteCommentParser | VoteCommentParser.java | 低 | 0.1d |
| 5.16 | ProfileParser | ProfileParser.java | 中 | 0.5d |
| 5.17 | EhHomeParser | EhHomeParser.java | 中 | 0.5d |
| 5.18 | MyTagLitParser | MyTagLitParser.java | 中 | 0.5d |
| 5.19 | EhEventParse | EhEventParse.java | 低 | 0.1d |

### Phase 6: Spider 图片引擎 [优先级: P0]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 6.1 | SpiderQueen 核心引擎 | SpiderQueen.java (1831行) | Swift Actor + TaskGroup | 3d |
| 6.2 | 三级优先级队列 | force/normal/preload queues | 自定义优先级队列 | 1d |
| 6.3 | pToken 分发机制 | QueenThread | 独立 Task + AsyncStream | 1d |
| 6.4 | SpiderDen 存储层 | SpiderDen.java | FileManager + URLCache | 1.5d |
| 6.5 | 磁盘缓存 (LRU) | SimpleDiskCache | 自定义 LRU 磁盘缓存 | 1.5d |
| 6.6 | SpiderInfo 读写 | SpiderInfo.java | Codable 序列化 | 0.5d |
| 6.7 | 509 检测 + 重试逻辑 | 内嵌于 downloadImage | 迁移核心重试逻辑 | 0.5d |
| 6.8 | 纯文本检测 | all bytes ≤ 126 check | Data 扫描 | 0.25d |
| 6.9 | 反劫持校验 | URL 对比检测 | URLResponse.url 比较 | 0.25d |

### Phase 7: 下载管理器 [优先级: P1]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 7.1 | DownloadManager | DownloadManager.java (1492行) | Swift Actor | 2d |
| 7.2 | 下载队列调度 | 串行调度 + 等待队列 | OperationQueue (maxConcurrency=1) | 1d |
| 7.3 | 速度测算 | SpeedReminder (指数移动平均) | Timer + 统计逻辑 | 0.5d |
| 7.4 | 标签分组系统 | label CRUD | SwiftData + @Observable | 0.5d |
| 7.5 | 后台下载服务 | DownloadService.kt (foreground) | BGTaskScheduler + URLSession background | 2d |
| 7.6 | 下载通知 | Notification + NotificationDelay | UNNotificationCenter + 延迟合并 | 1d |

### Phase 8: Gallery Provider (阅读器数据层) [优先级: P1]

| # | 任务 | Android 来源 | iOS 实现 | 估时 |
|---|------|-------------|---------|------|
| 8.1 | EhGalleryProvider | EhGalleryProvider.java | 桥接 SpiderQueen | 1d |
| 8.2 | DirGalleryProvider | DirGalleryProvider.java | FileManager 遍历 | 0.5d |
| 8.3 | ArchiveGalleryProvider | ArchiveGalleryProvider.java | ZIPFoundation / libarchive | 1.5d |

### Phase 9: UI 层 — 核心页面 [优先级: P1]

| # | 页面 | Android Scene | SwiftUI 实现 | 估时 |
|---|------|-------------|-------------|------|
| 9.1 | 主导航框架 | MainActivity + DrawerLayout | NavigationSplitView (iPad) | 2d |
| 9.2 | **画廊列表** | GalleryListScene | LazyVGrid + 搜索栏 | 3d |
| 9.3 | **画廊详情** | GalleryDetailScene | ScrollView + 标签/评论/预览 | 3d |
| 9.4 | **全屏阅读器** | GalleryActivity (OpenGL) | 自定义 PageView + 手势 | 5d |
| 9.5 | 收藏页面 | FavoritesScene | TabView (10分组) + 列表 | 2d |
| 9.6 | 下载管理页 | DownloadsScene | List + 进度条 + 标签 | 2d |
| 9.7 | 浏览历史 | HistoryScene | List + 滑动删除 | 1d |
| 9.8 | 排行榜 | EhTopListScene | 7 个 Section × 4 时间 | 1.5d |
| 9.9 | 评论页 | GalleryCommentsScene | List + HTML 渲染 | 1.5d |
| 9.10 | 预览网格 | GalleryPreviewsScene | LazyVGrid + 分页加载 | 1d |
| 9.11 | 搜索/高级过滤 | 内嵌在 GalleryListScene | Sheet + 分类选择器 | 1.5d |

### Phase 10: UI 层 — 辅助页面 [优先级: P2]

| # | 页面 | 估时 |
|---|------|------|
| 10.1 | 登录页 (账密 + WebView + Cookie) | 2d |
| 10.2 | 设置页面 (100+ 项) | 2d |
| 10.3 | 过滤器管理 | 1d |
| 10.4 | 黑名单管理 | 0.5d |
| 10.5 | 快速搜索管理 | 0.5d |
| 10.6 | Hosts 编辑器 | 1d |
| 10.7 | 标签订阅管理 | 1d |
| 10.8 | 我的标签页面 | 1d |
| 10.9 | 画廊信息详情页 | 0.5d |
| 10.10 | 新闻/活动页 | 0.5d |
| 10.11 | 配额/限制页 | 0.5d |

### Phase 11: 高级功能 [优先级: P2]

| # | 功能 | 估时 |
|---|------|------|
| 11.1 | 以图搜图 (拍照/相册) | 1d |
| 11.2 | 种子下载管理 | 1d |
| 11.3 | 归档下载 (服务器端压缩) | 1.5d |
| 11.4 | 剪贴板 URL 检测 | 0.5d |
| 11.5 | 数据库导入/导出 | 1d |
| 11.6 | 自动翻页功能 | 0.5d |
| 11.7 | 多语言支持 | 1d |

---

## 5. Android → iOS 差异预警

### 5.1 🔴 严重差异（需要重新设计）

| # | Android 功能 | iOS 问题 | 解决方案 |
|---|-------------|----------|----------|
| 1 | **前台 Service (DownloadService)** | iOS 无常驻前台服务 | `BGProcessingTask` + `URLSession.background` 双保险。后台下载时间有限（约 30s 处理时间），需用 `URLSession` 后台模式接管长时下载 |
| 2 | **OpenGL 画廊渲染** | iOS 已废弃 OpenGL ES | 使用 Metal 或纯 SwiftUI `TabView(.page)` + `AsyncImage`。推荐先用 SwiftUI 实现，性能不足再用 `UIPageViewController` |
| 3 | **多线程 Spider (synchronized/wait/notify)** | Swift 无 Java 同步原语 | 使用 Swift Actor + Task + AsyncStream 重写。优先级队列用 `TaskGroup` + 自定义调度器 |
| 4 | **自定义 SSL Socket (SNI 绕过)** | URLSession 不暴露底层 socket | 通过 `URLSessionDelegate.urlSession(_:didReceive:)` + `SecTrust` 自定义验证。或使用 NWConnection（Network.framework）进行底层 TLS 控制 |
| 5 | **内置 DNS (Hosts 文件)** | iOS 不支持系统级 hosts | `NWParameters.PrivacyContext` + 自定义 DNS resolver。或在 URLProtocol 层拦截并替换 IP |
| 6 | **Jsoup (HTML DOM 解析)** | iOS 无直接等价库 | 使用 `SwiftSoup` (Swift 移植的 Jsoup) — API 几乎一致 |
| 7 | **GIF 动画 (Native 解码)** | iOS 内置支持但 API 不同 | 使用 `SDWebImage` 或 Apple 原生 `ImageIO` |
| 8 | **7z 归档解压** | iOS 无内置 7z 支持 | 使用 `PLzmaSDK` 或 `SWCompression` 库 |

### 5.2 🟡 中等差异（需要适配）

| # | Android 功能 | iOS 适配方案 |
|---|-------------|-------------|
| 1 | WebView Cookie 同步 | WKWebView 使用 `WKHTTPCookieStore` 独立管理，需手动同步到 `HTTPCookieStorage` |
| 2 | 磁盘缓存 (SimpleDiskCache) | 使用 `URLCache` (HTTP 缓存) + 自定义 `FileManager` LRU 缓存 |
| 3 | SAF (Storage Access Framework) | iOS 使用 `FileManager` + Document Picker (`UIDocumentPickerViewController`) |
| 4 | SharedPreferences | `UserDefaults` + `@AppStorage` (SwiftUI) |
| 5 | GreenDAO ORM | `SwiftData` (iOS 17+) 或 `GRDB.swift` (更底层) |
| 6 | EventBus | `Combine` (Publisher/Subscriber) 或 `@Observable` + `@Environment` |
| 7 | AsyncTask | Swift `async/await` + `Task {}` |
| 8 | 代理设置 | `URLSessionConfiguration.connectionProxyDictionary` |
| 9 | 通知延迟合并 | `UNNotificationCenter` + 自定义 throttle 逻辑（Combine `.throttle`） |

### 5.3 🟢 无障碍迁移

| # | 功能 | 说明 |
|---|------|------|
| 1 | 正则表达式 | Swift `NSRegularExpression` 完全兼容 Java regex 语法 |
| 2 | JSON 解析 | Swift `Codable` / `JSONSerialization` |
| 3 | HTTP 网络请求 | `URLSession` 完全支持 GET/POST/Multipart |
| 4 | Cookie 持久化 | `HTTPCookieStorage.shared` 自动持久化 |
| 5 | 图片加载 | SDWebImage / Kingfisher / 原生 AsyncImage |
| 6 | 主题/暗模式 | SwiftUI 原生支持 `@Environment(\.colorScheme)` |

---

## 6. iPadOS 特化设计建议

### 6.1 利用 iPad 大屏优势

```
┌─────────────────────────────────────────────────────────┐
│ NavigationSplitView                                      │
│ ┌──────────┬────────────────────────────────────────────┐│
│ │ Sidebar  │ Detail                                     ││
│ │          │ ┌──────────────────────────────────────┐   ││
│ │ 🏠 首页   │ │     画廊网格 (LazyVGrid)             │   ││
│ │ 🔥 热门   │ │     ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │   ││
│ │ ⭐ 收藏   │ │     │   │ │   │ │   │ │   │ │   │ │   ││
│ │ 📥 下载   │ │     └───┘ └───┘ └───┘ └───┘ └───┘ │   ││
│ │ 📜 历史   │ │     ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ │   ││
│ │ 🏆 排行   │ │     │   │ │   │ │   │ │   │ │   │ │   ││
│ │ ⚙️ 设置   │ │     └───┘ └───┘ └───┘ └───┘ └───┘ │   ││
│ │          │ └──────────────────────────────────────┘   ││
│ └──────────┴────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

### 6.2 iPad 独有特性

| 特性 | 实现建议 |
|------|---------|
| **分屏多任务** | 支持 Split View / Slide Over |
| **键盘快捷键** | `⌘+F` 搜索, `←→` 翻页, `Space` 下一页 |
| **Drag & Drop** | 图片拖放保存/分享 |
| **Pencil 支持** | 手势导航（可选） |
| **Context Menu** | 长按画廊卡片 → 收藏/下载/分享 |
| **Spotlight 搜索** | 索引已下载/收藏的画廊到系统搜索 |
| **Stage Manager** | 支持多窗口（iPadOS 16+） |

### 6.3 阅读器 iPad 适配

| 模式 | 竖屏 | 横屏 |
|------|------|------|
| 单页模式 | 居中显示 | 居中显示 |
| 双页模式 | — | 左右并排（漫画阅读） |
| 长条模式 | 竖向无限滚动 | 竖向无限滚动 |
| 缩放 | 捏合缩放 + 双击 | 捏合缩放 + 双击 |

---

## 7. 技术选型推荐

### 7.1 框架选型

| 层次 | 推荐方案 | 备选 | 理由 |
|------|---------|------|------|
| **UI** | SwiftUI (iPadOS 16+) | — | 声明式 UI，iPad sidebar 原生支持 |
| **网络** | URLSession (原生) | Alamofire | 够用，减少依赖 |
| **HTML 解析** | SwiftSoup | Kanna (libxml) | SwiftSoup 是 Jsoup 的 Swift 移植，API 一致度最高，迁移正则/选择器几乎无改动 |
| **JSON** | Codable (原生) | — | Swift 标准 |
| **图片加载** | SDWebImage | Kingfisher | GIF/WebP 支持好，磁盘缓存成熟 |
| **数据库** | GRDB.swift | SwiftData | GRDB 更灵活，可精准复刻 GreenDAO 的查询模式 |
| **并发** | Swift Concurrency (Actor) | — | 替代 Java 的 synchronized/wait/notify |
| **缓存** | URLCache + 自定义 LRU | — | 替代 SimpleDiskCache |
| **归档** | ZIPFoundation + PLzmaSDK | — | ZIP + 7z 支持 |
| **路由** | SwiftUI NavigationStack | — | 替代 Scene/Stage 自定义栈 |
| **响应式** | @Observable (iOS 17) | Combine | 替代 EventBus |
| **WebView** | WKWebView (UIKit 包装) | — | WebView 登录方式 |

### 7.2 关键第三方库

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.18.0"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.53.0"),
]
```

---

## 8. 开发阶段排期

### 总览

| 阶段 | 内容 | 估时 | 累计 |
|------|------|------|------|
| **Alpha 1** | Model + DB + Network + Parser | ~25d | 25d |
| **Alpha 2** | Spider + Download + Gallery Provider | ~12d | 37d |
| **Beta 1** | 核心 UI (列表 + 详情 + 阅读器) | ~15d | 52d |
| **Beta 2** | 辅助 UI + 高级功能 | ~15d | 67d |
| **RC** | 测试 + 优化 + iPad 适配打磨 | ~10d | 77d |

### Alpha 1 详细排期 (第 1-5 周)

```
Week 1: Phase 0 (基建) + Phase 1 (数据模型)
Week 2: Phase 2 (数据库) + Phase 3 (网络层)
Week 3: Phase 4 (EhEngine API)
Week 4: Phase 5 (解析器 — 核心: GalleryList + GalleryDetail)
Week 5: Phase 5 (解析器 — 剩余) + 集成测试
```

### Alpha 2 详细排期 (第 6-8 周)

```
Week 6: Phase 6 (SpiderQueen 核心引擎)
Week 7: Phase 6 (缓存 + SpiderInfo) + Phase 7 (DownloadManager)
Week 8: Phase 7 (后台下载) + Phase 8 (Gallery Provider)
```

### Beta 1 详细排期 (第 9-11 周)

```
Week 9:  9.1 主导航框架 + 9.2 画廊列表页
Week 10: 9.3 画廊详情页 + 9.5 收藏页
Week 11: 9.4 全屏阅读器 (核心)
```

### Beta 2 详细排期 (第 12-14 周)

```
Week 12: 9.6-9.11 辅助核心页面
Week 13: Phase 10 (辅助页面)
Week 14: Phase 11 (高级功能)
```

### RC 阶段 (第 15-16 周)

```
Week 15: iPad 特化 + 性能优化 + 全屏阅读器打磨
Week 16: 全功能测试 + Bug 修复 + TestFlight
```

---

## 附录：文件映射速查表

| Android 文件 | iOS 对应建议 |
|-------------|-------------|
| `EhEngine.java` | `EhAPI.swift` (async/await) |
| `EhClient.java` | 废弃，直接用 async/await |
| `EhUrl.java` | `EhURL.swift` (enum) |
| `EhCookieStore.java` | `EhCookieManager.swift` |
| `EhConfig.java` | `EhConfig.swift` (struct) |
| `EhRequestBuilder.java` | `URLRequest+Eh.swift` (extension) |
| `Settings.java` | `AppSettings.swift` (@AppStorage) |
| `EhApplication.java` | `@main App` struct |
| `SpiderQueen.java` | `SpiderQueen.swift` (Actor) |
| `SpiderDen.java` | `SpiderDen.swift` (FileManager) |
| `SpiderInfo.java` | `SpiderInfo.swift` (Codable) |
| `DownloadManager.java` | `DownloadManager.swift` (Actor) |
| `DownloadService.kt` | 废弃，逻辑合并到 BGTask |
| `EhDB.java` | `EhDatabase.swift` (GRDB) |
| `GalleryInfo.java` | `GalleryInfo.swift` (struct) |
| `GalleryDetail.java` | `GalleryDetail.swift` (struct) |
| `ListUrlBuilder.java` | `ListURLBuilder.swift` (enum) |
| 21 个 Parser | 21 个 Swift Parser (SwiftSoup) |
| `MainActivity.java` | `ContentView.swift` (NavigationSplitView) |
| `GalleryActivity.java` | `GalleryReaderView.swift` |
| 各 Scene | 各 SwiftUI View |

---

> **总结**: 该 App 无加密/签名等黑盒逻辑，核心价值在于 **21 个精确的 HTML 解析器** 和 **高效的多线程图片引擎**。迁移的最大风险点是 HTML 解析器的正则/选择器精确复制，以及 iOS 后台下载能力的受限。建议 Parser 层采用 SwiftSoup (Jsoup 移植)，可最大限度保持选择器一致性，减少迁移错误。
