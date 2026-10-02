import AppKit
import Combine
import SwiftUI

@main
final class RightMenuHelper {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSSearchFieldDelegate {
    private var statusItem: NSStatusItem?
    private let store = ActionStore()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var menuOpen = false
    /// 搜索索引：数据变更时重建，搜索时快速命中
    private var searchIndex = SearchIndex()
    /// 当前搜索词；菜单被重建后由搜索框 delegate 回写以保持内容
    private var searchQuery = ""
    /// 当前搜索框（保留引用以便在重建菜单时恢复焦点与文字）
    private var searchField: NSSearchField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏工具，不占 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 使"开机自启动"配置与实际登录项状态保持一致
        LaunchAtLogin.apply()

        searchIndex.rebuild(with: store.actions)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.circle.fill", accessibilityDescription: "Quick Launch")
        }
        item.menu = buildMenu()
        statusItem = item

        // 配置变化时自动刷新菜单
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.searchIndex.rebuild(with: self.store.actions)
                self.statusItem?.menu = self.buildMenu()
            }
            .store(in: &cancellables)

        // 语言切换时自动刷新菜单
        NotificationCenter.default
            .publisher(for: Localizer.languageChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusItem?.menu = self?.buildMenu()
                self?.settingsWindow?.title = Localizer.t("FastLaunch 设置", "FastLaunch Settings")
            }
            .store(in: &cancellables)

        // 快捷键配置变化时重新注册并重建菜单（菜单项快捷键可能已修改）
        NotificationCenter.default
            .publisher(for: .hotKeyDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyHotKey()
                self?.statusItem?.menu = self?.buildMenu()
            }
            .store(in: &cancellables)

        // 全局快捷键：任意界面按下即呼出菜单
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.toggleMenu()
        }
        applyHotKey()
    }

    // MARK: - 全局快捷键

    private func applyHotKey() {
        guard HotKeyManager.isEnabled else {
            HotKeyManager.shared.unregister()
            return
        }
        let ok = HotKeyManager.shared.register(
            keyCode: HotKeyManager.storedKeyCode,
            modifiers: HotKeyManager.storedModifiers
        )
        if !ok {
            let alert = NSAlert()
            alert.messageText = Localizer.t("快捷键注册失败", "Hotkey registration failed")
            alert.informativeText = Localizer.t("该组合可能已被其他应用占用，请在设置中更换快捷键。", "The combination may already be used by another app. Change it in Settings.")
            alert.alertStyle = .warning
            alert.addButton(withTitle: Localizer.t("好", "OK"))
            alert.runModal()
        }
    }

    /// 呼出/收起菜单（全局快捷键触发）
    private func toggleMenu() {
        guard let button = statusItem?.button else { return }
        if menuOpen {
            statusItem?.menu?.cancelTracking()
        } else {
            button.performClick(nil)
        }
    }

    // MARK: - 菜单构建

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // 顶部搜索框（view-based item，点击输入不会关闭菜单）
        let searchField = NSSearchField()
        searchField.placeholderString = Localizer.t("搜索快捷项…", "Search shortcuts…")
        searchField.stringValue = searchQuery
        searchField.delegate = self
        searchField.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        let searchItem = NSMenuItem()
        searchItem.view = searchField
        menu.addItem(searchItem)
        menu.addItem(.separator())
        self.searchField = searchField

        // 列表部分
        appendResults(to: menu)

        let settingsItem = NSMenuItem(
            title: Localizer.t("设置…", "Settings…"),
            action: #selector(showSettings),
            keyEquivalent: MenuShortcutSettings.keyEquivalent(for: MenuShortcutSettings.keyCode(for: .settings))
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = MenuShortcutSettings.modifierMask(for: MenuShortcutSettings.modifiers(for: .settings))
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: Localizer.t("退出", "Quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: MenuShortcutSettings.keyEquivalent(for: MenuShortcutSettings.keyCode(for: .quit))
        )
        quitItem.keyEquivalentModifierMask = MenuShortcutSettings.modifierMask(for: MenuShortcutSettings.modifiers(for: .quit))
        menu.addItem(quitItem)

        return menu
    }

    /// 在菜单中追加快捷项列表（搜索框与底部固定项之间的内容）
    private func appendResults(to menu: NSMenu) {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            // 无搜索词：按类型分区展示全部
            let urlActions = store.urls
            if !urlActions.isEmpty {
                menu.addItem(headerItem(title: Localizer.t("常用网址", "Websites")))
                urlActions.forEach { menu.addItem(menuItem(for: $0)) }
                menu.addItem(.separator())
            }

            let appActions = store.apps
            if !appActions.isEmpty {
                menu.addItem(headerItem(title: Localizer.t("常用 App", "Apps")))
                appActions.forEach { menu.addItem(menuItem(for: $0)) }
                menu.addItem(.separator())
            }

            let fileActions = store.files
            if !fileActions.isEmpty {
                menu.addItem(headerItem(title: Localizer.t("常用文件 / 文件夹", "Files & Folders")))
                fileActions.forEach { menu.addItem(menuItem(for: $0)) }
                menu.addItem(.separator())
            }

            if urlActions.isEmpty && appActions.isEmpty && fileActions.isEmpty {
                let empty = NSMenuItem(title: Localizer.t("还没有快捷项，请在“设置”中添加", "No shortcuts yet. Add them in Settings."), action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
                menu.addItem(.separator())
            }
        } else {
            // 有搜索词：用索引快速过滤，并按相关度排序分组展示
            let results = searchIndex.search(query)
            if results.isEmpty {
                let noResult = NSMenuItem(
                    title: Localizer.t("没有匹配“\(query)”的快捷项", "No shortcuts match “\(query)”"),
                    action: nil,
                    keyEquivalent: ""
                )
                noResult.isEnabled = false
                menu.addItem(noResult)
                menu.addItem(.separator())
            } else {
                for type in QuickActionType.allCases {
                    let matched = results.filter { $0.type == type }
                    if matched.isEmpty { continue }
                    menu.addItem(headerItem(title: headerTitle(for: type)))
                    matched.forEach { menu.addItem(menuItem(for: $0)) }
                    menu.addItem(.separator())
                }
            }
        }
    }

    private func headerTitle(for type: QuickActionType) -> String {
        switch type {
        case .url: return Localizer.t("常用网址", "Websites")
        case .app: return Localizer.t("常用 App", "Apps")
        case .file: return Localizer.t("常用文件 / 文件夹", "Files & Folders")
        }
    }

    /// 搜索框内容变化时，就地替换列表部分（不重建搜索框，保住焦点与文字）
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        searchQuery = sender.stringValue
        guard let menu = statusItem?.menu else { return }
        // 搜索框 item 固定在第 0 位，紧随其后的第 1 位是分隔符；列表从第 2 位开始
        guard menu.items.count > 1, menu.items[1].isSeparatorItem else { return }
        let resultsStart = 2
        let settingsIndex = menu.items.firstIndex(where: { ($0.action == #selector(showSettings)) }) ?? menu.items.count
        // 倒序移除，避免索引错位
        if settingsIndex > resultsStart {
            for i in stride(from: settingsIndex - 1, through: resultsStart, by: -1) {
                menu.removeItem(at: i)
            }
        }
        // 追加新的列表项
        appendResults(to: menu)
    }

    private func headerItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func menuItem(for action: QuickAction) -> NSMenuItem {
        let item = NSMenuItem(title: action.name, action: #selector(openAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action
        let hasCommand = action.hasPreCommands
        // 文件/文件夹类型在名称下方附上实际路径；带前置操作的也提示一下
        let subtitle: String
        let symbol: String
        switch action.type {
        case .url:
            symbol = "globe"
            subtitle = hasCommand ? Localizer.t("先执行命令再打开网址", "Run command, then open URL") : ""
        case .app:
            symbol = "app.dashed"
            subtitle = hasCommand ? Localizer.t("先执行命令再打开 App", "Run command, then open app") : ""
        case .file:
            symbol = hasCommand ? "arrow.right.doc.on.clipboard" : "folder"
            subtitle = action.value
        }
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        if !subtitle.isEmpty {
            item.attributedTitle = twoLineTitle(title: action.name, subtitle: subtitle)
        }
        return item
    }

    /// 生成"主标题 + 副标题"的两行菜单文本
    private func twoLineTitle(title: String, subtitle: String) -> NSAttributedString {
        let main = NSMutableAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .regular)]
        )
        let sub = NSMutableAttributedString(
            string: "\n" + subtitle,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        main.append(sub)
        return main
    }

    // MARK: - 打开动作

    @objc private func openAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? QuickAction else { return }
        // 依次执行所有"打开前"命令步骤，最后打开目标
        runSteps(action.preCommands) { [weak self] in
            self?.launch(action)
        }
    }

    /// 依次执行多条命令；每条执行完后等待其 delayAfter 秒，再执行下一条
    private func runSteps(_ steps: [PreCommandStep], completion: @escaping () -> Void) {
        guard let first = steps.first else {
            completion()
            return
        }
        runCommand(first.command) { [weak self] in
            let delay = max(0, first.delayAfter)
            if steps.count == 1 {
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { completion() }
                } else {
                    completion()
                }
                return
            }
            // 还有后续步骤：先等待间隔，再递归执行
            let rest = Array(steps.dropFirst())
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.runSteps(rest, completion: completion)
                }
            } else {
                self?.runSteps(rest, completion: completion)
            }
        }
    }

    private func launch(_ action: QuickAction) {
        switch action.type {
        case .url: openURL(action.value)
        case .app: openApp(path: action.value)
        case .file: openFile(path: action.value)
        }
    }

    /// 打开文件或文件夹（在 Finder 或默认应用中打开）
    private func openFile(path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            reportOpenFailure(name: url.lastPathComponent, error: NSError(domain: "FastLaunch", code: -1, userInfo: [NSLocalizedDescriptionKey: "File not found"]))
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// 在后台执行一条 shell 命令，完成后回到主线程执行 completion
    private func runCommand(_ command: String, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                // 前置命令执行失败时仍继续打开目标
            }
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func openURL(_ raw: String) {
        var urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openApp(path: String) {
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                self?.reportOpenFailure(name: url.deletingPathExtension().lastPathComponent, error: error)
            }
        }
    }

    private func reportOpenFailure(name: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = Localizer.t("无法打开“\(name)”", "Unable to open “\(name)”")
        alert.informativeText = Localizer.t("该 App 可能已被移动或删除，请到设置中更新。\n\(error.localizedDescription)", "The app may have been moved or deleted. Update it in Settings.\n\(error.localizedDescription)")
        alert.alertStyle = .warning
        alert.addButton(withTitle: Localizer.t("好", "OK"))
        if let window = settingsWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    // MARK: - 设置窗口

    @objc private func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(store: store)
            let hosting = NSHostingController(rootView: settingsView)
            let window = NSWindow(contentViewController: hosting)
            window.title = Localizer.t("FastLaunch 设置", "FastLaunch Settings")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setFrameAutosaveName("RightMenuHelperSettings")
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 菜单开关状态（供全局快捷键 toggle 使用）

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        // 菜单打开后聚焦搜索框，使用户可直接输入（无需先点击）
        DispatchQueue.main.async { [weak self] in
            guard let self, let field = self.searchField else { return }
            if let window = field.window {
                window.makeFirstResponder(field)
            }
            _ = field.becomeFirstResponder()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
    }
}
