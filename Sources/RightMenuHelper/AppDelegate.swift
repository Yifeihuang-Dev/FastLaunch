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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = ActionStore()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var menuOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏工具，不占 Dock 图标
        NSApp.setActivationPolicy(.accessory)

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
                self?.statusItem?.menu = self?.buildMenu()
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

        // 快捷键配置变化时重新注册
        NotificationCenter.default
            .publisher(for: .hotKeyDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyHotKey()
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

        if urlActions.isEmpty && appActions.isEmpty {
            let empty = NSMenuItem(title: Localizer.t("还没有快捷项，请在“设置”中添加", "No shortcuts yet. Add them in Settings."), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: Localizer.t("设置…", "Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: Localizer.t("退出", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
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
        let hasCommand = !(action.preCommand?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let symbol = hasCommand ? "arrow.right.circle" : (action.type == .url ? "globe" : "app.dashed")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: hasCommand ? Localizer.t("带前置操作", "with pre-action") : nil)
        return item
    }

    // MARK: - 打开动作

    @objc private func openAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? QuickAction else { return }
        // 先执行可选的"打开前操作"，完成后再打开目标
        if let cmd = action.preCommand, !cmd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runCommand(cmd) { [weak self] in
                self?.launch(action)
            }
        } else {
            launch(action)
        }
    }

    private func launch(_ action: QuickAction) {
        switch action.type {
        case .url: openURL(action.value)
        case .app: openApp(path: action.value)
        }
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
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
    }
}
