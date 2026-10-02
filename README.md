# FastLaunch

> A macOS menu-bar launcher — one global hotkey to open your favorite websites, apps, and files.

FastLaunch is a lightweight macOS menu-bar utility (LSUIElement, no Dock icon). It keeps your most-used **websites**, **apps**, and **files/folders** in one customizable menu, summoned from the menu bar or a **global hotkey**. You can even attach multiple pre-launch shell commands to any shortcut (e.g. connect a VPN first, then open the app), and search everything instantly.

---

## Features

- **Menu-bar resident** — lives in the top menu bar with a ⚡ icon and near-zero resource usage.
- **Global hotkey** — summon the menu from anywhere with `⌥⌘L` (Option + Command + L) by default; fully customizable and toggleable.
- **Websites, apps & files** — one menu for all three kinds of shortcuts, each group managed and reordered independently. File items show their actual path under the title.
- **Instant search** — a built-in search field at the top of the menu filters shortcuts as you type, with pre-lowercased indexes, multi-token matching, and relevance ranking.
- **Pre-launch commands** — attach any number of shell commands to a shortcut, executed in order with a configurable wait interval between each, before the target opens.
- **Shortcut manager** — view and re-record every app shortcut (global hotkey, Open Settings, Quit), plus any per-app shortcuts you've added in macOS System Settings (App Shortcuts), which can be removed right from the panel.
- **Launch at login** — optional (off by default), managed via `SMAppService`.
- **Bilingual UI** — English / Simplified Chinese, defaulting to English, switchable anytime.
- **Persistent config** — everything is saved automatically and survives restarts.

## Tech Stack

| Item | Details |
|---|---|
| Language | Swift |
| UI | SwiftUI (settings panel) + AppKit (menu bar & actions) |
| Project | Swift Package Manager (no Xcode project needed) |
| Requirements | macOS 13.0+ |
| Menu bar | `NSStatusItem` + `NSMenu` |
| Global hotkey | `NSEvent.addGlobalMonitorForEvents` |
| Opening targets | `NSWorkspace.shared.open` |
| Storage | `UserDefaults` |

## Project Structure

```
FastLaunch/
├── Package.swift                    # SPM manifest
├── build.sh                         # build & bundle FastLaunch.app in one step
├── Resources/
│   └── Info.plist                   # app metadata (LSUIElement=true)
├── Assets/
│   └── AppIcon.icns                 # app icon
└── Sources/RightMenuHelper/
    ├── Models.swift                 # data models (QuickAction, PreCommandStep)
    ├── ActionStore.swift            # persistence & CRUD
    ├── AppDelegate.swift            # status item, menu building, launch logic, hotkeys
    ├── HotKeyManager.swift          # global hotkey registration & recording
    ├── SearchIndex.swift            # fast in-menu search with ranked results
    ├── ShortcutSettings.swift       # menu shortcut storage & system app shortcuts
    ├── LaunchAtLogin.swift          # SMAppService login item
    ├── Localizer.swift              # EN/CN localization
    └── SettingsView.swift           # SwiftUI settings panel
```

## Getting Started

### Option 1: Build & run locally

```bash
./build.sh          # compiles and bundles FastLaunch.app
open FastLaunch.app # run it
```

### Option 2: Build from source (recommended for other Macs — no Gatekeeper warnings)

```bash
git clone https://github.com/Yifeihuang-Dev/FastLaunch.git
cd FastLaunch
./build.sh
open FastLaunch.app
```

Binaries compiled on your own machine carry no quarantine attribute, so they open with a plain double-click.

### Option 3: Install from the dmg

Open `FastLaunch.dmg` and drag `FastLaunch.app` into your Applications folder. Since the app is unsigned, on first launch **Control-click the icon → Open** once to bypass Gatekeeper.

## Usage

1. Click the ⚡ icon in the menu bar, or press the global hotkey `⌥⌘L`.
2. Click any item to open its website / app / file. If pre-launch commands are configured, they run first (with their wait intervals), then the target opens.
3. Use the search field at the top of the menu to filter shortcuts instantly.
4. In the settings panel you can:
   - switch the UI language
   - toggle / re-record the global hotkey, menu shortcuts, and review system app shortcuts
   - add, edit, delete, and reorder shortcuts (websites, apps, files/folders)
   - edit multi-step pre-launch commands with delays
   - enable launch-at-login

## License

For personal use and learning only. The app is not signed or notarized with an Apple Developer account, so macOS may show a security prompt when distributing across machines — this is expected behavior.
