# FastLaunch

> macOS 菜单栏快速启动工具 —— 一个全局快捷键，随时打开常用网址与应用。

FastLaunch 是一款轻量级的 macOS 菜单栏常驻小工具（LSUIElement，无 Dock 图标）。它把你最常用的**网址**和 **App** 收进一个可自定义的快捷菜单，通过菜单栏图标或**全局快捷键**一键呼出、点击即打开。你甚至可以给每个快捷项配置一条"打开前先执行的命令"（比如先开启某项设置，再启动某个 App）。

---

## 功能特性

- **菜单栏常驻**：常驻顶部菜单栏，占用资源极低，点击 ⚡ 图标即弹出快捷菜单。
- **全局快捷键呼出**：默认 `⌥⌘L`（Option + Command + L），在任何应用里都能一键呼出菜单；快捷键可自定义、可开关。
- **网址 & App 混排**：一个菜单里同时支持"常用网址"和"常用 App"，两者可分别管理、排序。
- **完全自定义**：每个快捷项的名称、目标（网址或 App）、顺序都可自由配置。
- **前置命令**：可选地为某个快捷项设置一条 shell 命令，先执行再打开目标（例如：先连接 VPN / 开启勿扰 / 启动某项服务，再打开对应 App）。
- **中英双语**：界面支持跟随系统 / 简体中文 / English，默认英文，随时切换。
- **配置持久化**：所有设置自动保存，重启不丢失。

## 技术栈

| 项 | 说明 |
|---|---|
| 语言 | Swift |
| 界面 | SwiftUI（设置面板）+ AppKit（菜单栏 & 打开动作） |
| 工程 | Swift Package Manager（无需 Xcode 工程） |
| 系统要求 | macOS 13.0+ |
| 状态栏 | NSStatusItem + NSMenu |
| 全局热键 | `NSEvent.addGlobalMonitorForEvents` |
| 打开目标 | `NSWorkspace.shared.open` |
| 配置存储 | `UserDefaults` |

## 工程结构

```
FastLaunch/
├── Package.swift                    # SPM 工程定义
├── build.sh                         # 一键编译 + 打包 .app
├── Resources/
│   └── Info.plist                   # 应用元信息（LSUIElement=true）
├── Assets/
│   └── AppIcon.icns                 # 应用图标
└── Sources/RightMenuHelper/
    ├── Models.swift                 # 数据模型（QuickAction）
    ├── ActionStore.swift            # 配置读写、增删改排
    ├── AppDelegate.swift            # 状态栏、菜单构建、打开逻辑、热键集成
    ├── HotKeyManager.swift          # 全局热键注册 / 录制
    ├── Localizer.swift              # 中英双语本地化
    └── SettingsView.swift           # SwiftUI 设置面板
```

## 快速开始

### 方式一：直接运行（本机）

```bash
./build.sh          # 编译并打包出 FastLaunch.app
open FastLaunch.app # 运行
```

### 方式二：从源码编译（推荐给其他 Mac 用户，无签名警告）

```bash
git clone https://github.com/Yifeihuang-Dev/FastLaunch.git
cd FastLaunch
./build.sh
open FastLaunch.app
```

本机编译产物无隔离标记，可直接双击打开。

### 方式三：安装版（dmg）

解压 `FastLaunch.dmg`，将 `FastLaunch.app` 拖入「应用程序」文件夹。首次打开如遇系统拦截，请在图标上**按住 Control 单击 → 打开**一次即可。

## 使用说明

1. 启动后点菜单栏 ⚡ 图标，或按全局快捷键 `⌥⌘L` 呼出菜单。
2. 点击某项即打开对应网址 / App；若该项配置了前置命令，会先执行命令再打开目标。
3. 在设置面板中：
   - 切换界面语言
   - 开关 / 修改全局快捷键
   - 添加、编辑、删除、上移 / 下移快捷项

## 许可

仅个人使用与学习交流。本工具未经 Apple 开发者签名与公证，跨设备分发时 macOS 可能弹出安全提示，属正常现象。
