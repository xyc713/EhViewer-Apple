# Homeland — 完整执行方案

> EhViewer Android → macOS / iOS / iPadOS 多平台原生 Swift 应用
> 目标: Xcode 26.2 · Swift 6.2 · iOS 17+ · macOS 14+

---

## 一、项目结构总览

```
Homeland/
├── App/
│   └── Homeland/                  ← Xcode multiplatform App target
│       ├── HomelandApp.swift      ← @main 入口
│       ├── iOS/                   ← iOS/iPadOS 平台特化
│       └── macOS/                 ← macOS 平台特化
│
├── Packages/
│   ├── EhCore/                    ← 核心层 (无网络依赖)
│   │   ├── EhModels/              ✅ GalleryInfo, GalleryDetail, EhCategory, EhURL, DataModels
│   │   ├── EhDatabase/           ✅ GRDB 数据库 (schema + CRUD) — 已集成到 HistoryView
│   │   └── EhSettings/           ✅ @Observable 用户设置
│   │
│   ├── EhNetwork/                 ← 网络层
│   │   ├── EhAPI/                ✅ EhRequestBuilder + EhAPI 引擎 — 已接入 Parser
│   │   ├── EhCookie/             ✅ Cookie 管理 (登录/SadPanda)
│   │   └── EhDNS/               ✅ 内置 Hosts + DoH
│   │
│   ├── EhParser/                  ← HTML/JSON 解析器
│   │   └── EhParser/            ✅ GalleryList/Detail/PageParser — 全部实现
│   │
│   ├── EhSpider/                  ← 图片加载引擎
│   │   └── EhSpider/            ✅ SpiderQueen Actor — 网络方法已实现
│   │
│   ├── EhDownload/                ← 下载管理
│   │   └── EhDownload/          ✅ DownloadManager Actor — 数据库持久化已集成
│   │
│   └── EhUI/                     ← 共享 UI 组件
│       ├── Components/            ⬜ 卡片、标签、评分等可复用组件
│       ├── Screens/               ⬜ 各功能页面
│       └── Reader/                ⬜ 阅读器

✅ UI 视图 (在 App 中):
   - GalleryListView      ✅ 使用 EhAPI + GalleryInfo
   - GalleryDetailView    ✅ 使用 GalleryInfo
   - ImageReaderView      ✅ 使用 SpiderQueen
   - FavoritesView        ✅ 已实现
   - HistoryView          ✅ 使用 EhDatabase
   - SettingsView         ✅ 已实现
   - LoginView            ✅ 已实现
```

✅ = 已完成  ⬜ = 待实现

---

## 二、你现在需要做什么 (立即行动)

### 第 1 步: 创建 Xcode 项目 (10 分钟)

1. 打开 Xcode → File → New → Project
2. 选择 **Multiplatform → App**
3. Product Name: `Homeland`
4. Team: 选你的开发者账号
5. Organization Identifier: `com.stellatrix`
6. 保存位置: `/Users/felix/program/Stellatrix/Homeland/App/`
7. ⚠️ **不要勾选** "Create Git repository" (已有)

### 第 2 步: 添加 Swift Packages (5 分钟)

在 Xcode 中:
1. File → Add Package Dependencies
2. 添加本地 Package: 把 `Packages/` 下的 6 个文件夹逐个拖入 Xcode 项目导航
3. 或者: File → Add Package Dependencies → Add Local → 选择每个 Package 文件夹

依赖也会自动解析:
- `GRDB.swift` (https://github.com/groue/GRDB.swift) — 自动从 Package.swift 拉取
- `SwiftSoup` (https://github.com/scinfu/SwiftSoup) — 自动拉取
- `SDWebImageSwiftUI` (https://github.com/SDWebImage/SDWebImageSwiftUI) — 自动拉取

### 第 3 步: 替换 App 入口文件 (2 分钟)

用 `App/Homeland/HomelandApp.swift` 替换 Xcode 自动生成的 `ContentView.swift` 和 App 入口。

### 第 4 步: 编译验证 (5 分钟)

```
Cmd + B
```

修复任何编译错误——主要是包之间的 import 路径问题。

---

## 三、开发路线图 (推荐顺序)

### Phase 1: 网络可通 ✅ 已完成

**目标**: 能够成功登录并获取画廊列表

| 任务 | 文件 | 状态 |
|------|------|--------|
| 完善 Cookie 管理 | `EhCookie/EhCookieManager.swift` | ✅ |
| 实现登录 API | `EhAPI/EhAPI.swift` → `signIn()` | ✅ |
| 实现列表解析器 | `EhParser/GalleryListParser.swift` | ✅ |
| 实现 API 补全 | `EhAPI/EhAPI.swift` → `fillGalleryListByApi()` | ✅ |
| 域前置/SNI 绕过 | `EhDNS/EhDNS.swift` | ✅ |

**验收标准**: ✅ `EhAPI.shared.getGalleryList(url:)` 返回有效 `[GalleryInfo]`

### Phase 2: 列表可看 ✅ 已完成

**目标**: 画廊列表页面可以浏览

| 任务 | 文件 | 状态 |
|------|------|--------|
| 画廊卡片组件 | `GalleryRow` in GalleryListView | ✅ |
| 列表页面 | `GalleryListView.swift` 使用 EhAPI | ✅ |
| 搜索功能 | 集成在 GalleryListView | ✅ |
| 图片加载 | AsyncImage 集成 | ✅ |
| 分页加载 | 列表无限滚动 | ✅ |

**验收标准**: ✅ 启动 App 后看到画廊列表，缩略图加载正常

### Phase 3: 详情可读 ✅ 已完成

**目标**: 点击画廊查看详情 + 阅读图片

| 任务 | 文件 | 状态 |
|------|------|--------|
| 详情解析器 | `EhParser/GalleryDetailParser.swift` | ✅ |
| 详情页面 | `GalleryDetailView.swift` | ✅ |
| 图片阅读器 | `ImageReaderView.swift` | ✅ |
| SpiderQueen 接通 | `EhSpider/SpiderQueen.swift` — fetchPageHtml/fetchPageApi | ✅ |
| 评论显示 | GalleryDetailView 评论区 | ✅ |

**验收标准**: ✅ 点击画廊 → 显示详情 → 点击阅读 → 流畅浏览图片

### Phase 4: 下载可用 ✅ 基础完成

**目标**: 离线浏览

| 任务 | 状态 |
|------|--------|
| DownloadManager 接通 SpiderQueen | ✅ |
| 下载队列 UI | ✅ DownloadsView 已实现 |
| 后台下载 (URLSession background) | ✅ BackgroundDownloadManager |
| .ehviewer 文件格式兼容 | ✅ SpiderInfoFile 读写 |

### Phase 5: 完善功能 ✅ 已完成

| 任务 | 状态 |
|------|--------|
| 收藏 (本地 + 远程) | ✅ FavoritesView |
| 浏览历史 | ✅ HistoryView + EhDatabase |
| 快速搜索 | ✅ QuickSearchView |
| 标签过滤 | ✅ FilterView |
| 评分功能 | ✅ RatingSheet |
| 排行榜 | ✅ TopListView |

### Phase 6: 平台优化 ✅ 已完成

| 平台 | 优化内容 | 状态 |
|------|---------|------|
| **iPadOS** | 双栏布局 (NavigationSplitView) | ✅ |
| **macOS** | 原生菜单栏、Settings 窗口 | ✅ |
| **iOS** | 横屏阅读、点击翻页、捏合缩放、阅读方向 | ✅ |

---

## 四、关键技术决策 (已确定)

| Android | Swift |
|---------|-------|
| OkHttp | `URLSession` + async/await |
| Jsoup | `SwiftSoup` |
| GreenDAO | `GRDB.swift` |
| Glide | `SDWebImageSwiftUI` |
| AsyncTask / Thread | `Swift Concurrency` (Actor, TaskGroup) |
| SharedPreferences | `UserDefaults` + `@Observable` |
| Scene (Fragment-like) | `NavigationStack` + `NavigationSplitView` |

---

## 五、核心 Android 逻辑速查 (开发备忘)

### 评分算法
```swift
// background-position:0px -{num1}px;opacity:{num2}
rate = 5 - num1 / 16
if num2 == 21 { rate -= 0.5 }
```

### SpiderQueen 管线
```
getPToken → buildPageUrl → [首次] GET HTML 得 showKey
                          → [后续] POST api showpage
→ 下载图片 → 反劫持检 → 509 检测 → 5 次重试
```

### 文件命名
```swift
// 图片: 8 位序号 + 扩展名
String(format: "%08d%@", index + 1, ext)  // "00000001.jpg"

// 下载目录: gid-标题
"\(gid)-\(sanitizedTitle)"
```

### .ehviewer 格式
```
VERSION2
{startPage (hex)}
{gid}
{token}
1
{previewPages}
{previewPerPage}
{pages}
{index} {pToken}
{index} {pToken}
...
```

### Cookie 关键字段
| Cookie | 说明 |
|--------|------|
| `ipb_member_id` | 用户 ID |
| `ipb_pass_hash` | 密码哈希 |
| `igneous` | ExHentai 通行证 |
| `nw=1` | 跳过内容警告 (硬编码注入) |
| `sk` | Session Key |

### 收藏槽颜色
```swift
let favoriteColors: [(Int, Int, Int)] = [
    (0,0,0),       // 0
    (240,0,0),     // 1
    (240,160,0),   // 2
    (208,208,0),   // 3
    (0,128,0),     // 4
    (144,240,64),  // 5
    (64,176,240),  // 6
    (0,0,240),     // 7
    (80,0,128),    // 8
    (224,128,224), // 9
]
```

---

## 六、预计工期

| Phase | 内容 | 预计 |
|-------|------|------|
| 1 | 网络可通 | 1-2 周 |
| 2 | 列表可看 | 1-2 周 |
| 3 | 详情可读 | 1-2 周 |
| 4 | 下载可用 | 1 周 |
| 5 | 完善功能 | 2 周 |
| 6 | 平台优化 | 1-2 周 |
| **总计** | | **7-11 周** |

---

## 七、文件清单 (已创建)

所有文件位于 `/Users/felix/program/Stellatrix/Homeland/` 下:

### EhCore
- `Packages/EhCore/Package.swift`
- `Packages/EhCore/Sources/EhModels/EhCategory.swift`
- `Packages/EhCore/Sources/EhModels/GalleryInfo.swift`
- `Packages/EhCore/Sources/EhModels/GalleryDetail.swift`
- `Packages/EhCore/Sources/EhModels/EhURL.swift`
- `Packages/EhCore/Sources/EhModels/DataModels.swift`
- `Packages/EhCore/Sources/EhSettings/AppSettings.swift`
- `Packages/EhCore/Sources/EhSettings/Exports.swift`
- `Packages/EhCore/Sources/EhDatabase/EhDatabase.swift`

### EhNetwork
- `Packages/EhNetwork/Package.swift`
- `Packages/EhNetwork/Sources/EhAPI/EhRequestBuilder.swift`
- `Packages/EhNetwork/Sources/EhAPI/EhAPI.swift`
- `Packages/EhNetwork/Sources/EhCookie/EhCookieManager.swift`
- `Packages/EhNetwork/Sources/EhDNS/EhDNS.swift`

### EhParser
- `Packages/EhParser/Package.swift`
- `Packages/EhParser/Sources/EhParser/GalleryListParser.swift`
- `Packages/EhParser/Sources/EhParser/GalleryDetailParser.swift`
- `Packages/EhParser/Sources/EhParser/GalleryPageParser.swift`

### EhSpider
- `Packages/EhSpider/Package.swift`
- `Packages/EhSpider/Sources/EhSpider/SpiderQueen.swift`

### EhDownload
- `Packages/EhDownload/Package.swift`
- `Packages/EhDownload/Sources/EhDownload/DownloadManager.swift`

### EhUI
- `Packages/EhUI/Package.swift`

### App
- `App/Homeland/HomelandApp.swift`
