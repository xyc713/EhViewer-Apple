# EhViewer-Apple

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B%20%7C%20macOS%2014%2B-blue" alt="Platform"/>
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift 6.0"/>
  <img src="https://img.shields.io/badge/license-Apache%202.0-green" alt="License"/>
</p>

EhViewer-Apple 是一款适用于 iOS 和 macOS 的 [E-Hentai](https://e-hentai.org) / [ExHentai](https://exhentai.org) 画廊浏览客户端，使用 SwiftUI 原生构建。

> **致敬**: 本项目灵感来源于 Android 端的 [EhViewer](https://github.com/Ehviewer-Overhauled/Ehviewer) 和 [EhViewer_CN_SXJ](https://github.com/xiaojieonly/Ehviewer_CN_SXJ)，感谢原作者的出色工作。

---

## ✨ 功能特性

- 🔍 **画廊浏览** — 支持热门、最新、收藏、排行榜等多种浏览方式
- 🔎 **高级搜索** — 分类筛选、关键词、标签搜索、快速搜索收藏
- 📖 **阅读器** — 横向翻页 / 纵向滚动，支持缩放、手势操作
- ⬇️ **下载管理** — 后台下载、断点续传、通知提醒
- ⭐ **收藏管理** — 多文件夹收藏同步
- 🔐 **安全保护** — Face ID / Touch ID / 密码锁
- 🌐 **网络优化** — Domain Fronting 回退、DNS over HTTPS
- 🖥️ **多平台** — iOS / iPadOS / macOS 原生体验

## 📦 项目结构

```
EhViewer-Apple/
├── ehviewer apple/              # 主 App 目标
│   ├── *View.swift              # SwiftUI 视图层
│   ├── ehviewer_appleApp.swift  # App 入口
│   └── Assets.xcassets/         # 资源文件
├── Packages/                    # Swift Package 模块化架构
│   ├── EhCore/                  # 核心模型、数据库、设置
│   │   ├── EhModels/            #   数据模型
│   │   ├── EhDatabase/          #   GRDB 数据库
│   │   └── EhSettings/          #   全局配置
│   ├── EhNetwork/               # 网络层
│   │   ├── EhAPI/               #   API 请求引擎
│   │   ├── EhCookie/            #   Cookie 管理
│   │   └── EhDNS/               #   DNS 与域名前置
│   ├── EhParser/                # HTML/JSON 解析器
│   ├── EhSpider/                # 图片抓取引擎
│   ├── EhDownload/              # 下载管理器
│   └── EhUI/                    # 可复用 UI 组件
└── ehviewer apple.xcodeproj/    # Xcode 工程文件
```

## 🛠️ 环境要求

| 项目 | 最低版本 |
|------|---------|
| Xcode | 16.0+ |
| Swift | 6.0 |
| iOS | 17.0+ |
| macOS | 14.0+ (Sonoma) |

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/felixchaos/EhViewer-Apple.git
cd EhViewer-Apple
```

### 2. 打开项目

```bash
open "ehviewer apple.xcodeproj"
```

### 3. 构建运行

在 Xcode 中选择目标设备（iPhone / Mac），按 `⌘R` 运行。

> **注意**: Swift Package 依赖会在首次打开时自动解析，请确保网络畅通。

## 📱 截图

<!-- 
TODO: 添加 App 截图
<p align="center">
  <img src="screenshots/home.png" width="200"/>
  <img src="screenshots/reader.png" width="200"/>
  <img src="screenshots/download.png" width="200"/>
</p>
-->

*截图即将添加*

## 🤝 参与贡献

欢迎贡献代码！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解贡献流程。

简要步骤：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: 添加某个功能'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📋 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解版本历史和更新内容。

## 📄 开源协议

本项目基于 [Apache License 2.0](LICENSE) 协议开源 — 查看 [LICENSE](LICENSE) 文件获取详细信息。

## 🙏 致谢

- [EhViewer](https://github.com/Ehviewer-Overhauled/Ehviewer) — Android 端 EhViewer
- [EhViewer_CN_SXJ](https://github.com/xiaojieonly/Ehviewer_CN_SXJ) — Android 端中文增强版
- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite 数据库工具包

## ⚠️ 免责声明

本项目仅供学习和技术交流使用。用户应遵守当地法律法规，开发者不对使用本软件产生的任何后果承担责任。

---

<p align="center">
  <sub>使用 ❤️ 和 SwiftUI 构建</sub>
</p>
