import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: ActionStore
    @AppStorage(Localizer.preferenceKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(HotKeyManager.enabledPrefKey) private var hotKeyEnabled = true
    @AppStorage(LaunchAtLogin.preferenceKey) private var launchAtLogin = false
    @State private var showAddURL = false
    @State private var showAddApp = false
    @State private var showAddFile = false
    @State private var editingItem: QuickAction?
    /// 当前正在录制的快捷键目标（nil 表示未在录制）
    @State private var recordingTarget: ShortcutRecordingTarget?
    /// 用户通过 macOS 系统设置添加的 App 快捷键列表
    @State private var systemShortcuts: [SystemAppShortcut] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Localizer.t("语言 / Language", "Language"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                Picker("", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 240)
                Spacer()
            }

            // 开机自启动
            Toggle(Localizer.t("开机自启动", "Launch at login"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    LaunchAtLogin.isEnabled = enabled
                }

            Divider()

            // 快捷键管理
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Localizer.t("快捷键", "Shortcuts"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(Localizer.t("全部恢复默认", "Reset All")) {
                        HotKeyManager.save(keyCode: HotKeyManager.defaultKeyCode, modifiers: HotKeyManager.defaultModifiers)
                        MenuShortcutSettings.reset(kind: .settings)
                        MenuShortcutSettings.reset(kind: .quit)
                        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                Toggle(Localizer.t("启用全局快捷键（任意界面呼出菜单）", "Enable global hotkey (open menu anywhere)"), isOn: $hotKeyEnabled)

                // 全局呼出
                HStack(spacing: 8) {
                    Text(Localizer.t("全局呼出菜单", "Open menu globally"))
                        .foregroundColor(hotKeyEnabled ? .primary : .secondary)
                    Spacer()
                    if recordingTarget == .globalHotkey {
                        Text(Localizer.t("按下组合键…（Esc 取消）", "Press combination… (Esc to cancel)"))
                            .foregroundColor(.accentColor)
                    } else {
                        shortcutBadge(HotKeyManager.description(
                            keyCode: HotKeyManager.storedKeyCode,
                            modifiers: HotKeyManager.storedModifiers
                        ))
                        .opacity(hotKeyEnabled ? 1 : 0.4)
                    }
                    Button(Localizer.t("修改", "Change")) { startRecording(.globalHotkey) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!hotKeyEnabled)
                    Button(Localizer.t("默认", "Reset")) {
                        HotKeyManager.save(keyCode: HotKeyManager.defaultKeyCode, modifiers: HotKeyManager.defaultModifiers)
                        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!hotKeyEnabled || (HotKeyManager.storedKeyCode == HotKeyManager.defaultKeyCode && HotKeyManager.storedModifiers == HotKeyManager.defaultModifiers))
                }

                // 打开设置…
                shortcutRow(
                    title: Localizer.t("打开设置…", "Open Settings…"),
                    description: MenuShortcutSettings.description(kind: .settings),
                    isRecording: recordingTarget == .menuSettings,
                    target: .menuSettings,
                    kind: .settings
                )

                // 退出
                shortcutRow(
                    title: Localizer.t("退出 FastLaunch", "Quit FastLaunch"),
                    description: MenuShortcutSettings.description(kind: .quit),
                    isRecording: recordingTarget == .menuQuit,
                    target: .menuQuit,
                    kind: .quit
                )

                Text(Localizer.t("需包含 ⌘ ⌥ ⌃ ⇧ 中至少一个修饰键", "Must include at least one modifier key (⌘ ⌥ ⌃ ⇧)"))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Divider()

                // 系统 App 快捷键（用户在 macOS 设置中为 FastLaunch 添加的）
                HStack {
                    Text(Localizer.t("系统 App 快捷键", "System App Shortcuts"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                if systemShortcuts.isEmpty {
                    Text(Localizer.t("暂无。可到 系统设置 → 键盘 → 键盘快捷键 → App 快捷键 中为 FastLaunch 添加。", "None. Add in System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts for FastLaunch."))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(systemShortcuts) { shortcut in
                        HStack(spacing: 8) {
                            Text(shortcut.menuTitle)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(SystemAppShortcuts.displayText(for: shortcut.keyString))
                                .font(.system(.caption, design: .monospaced))
                            Button {
                                SystemAppShortcuts.remove(menuTitle: shortcut.menuTitle)
                                reloadSystemShortcuts()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .help(Localizer.t("删除此快捷键", "Remove this shortcut"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
                Text(Localizer.t("系统 App 快捷键由 macOS 分发，修改后重新打开应用即可生效。", "System app shortcuts are handled by macOS; reopen the app after changes."))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            section(
                title: Localizer.t("常用网址", "Websites"),
                addTitle: Localizer.t("添加网址", "Add Website"),
                items: store.urls,
                placeholder: Localizer.t("还没有网址，点击右上角“添加网址”", "No websites yet. Click “Add Website” above."),
                addAction: { showAddURL = true }
            )

            Divider()

            section(
                title: Localizer.t("常用 App", "Apps"),
                addTitle: Localizer.t("添加 App", "Add App"),
                items: store.apps,
                placeholder: Localizer.t("还没有 App，点击右上角“添加 App”", "No apps yet. Click “Add App” above."),
                addAction: { showAddApp = true }
            )

            Divider()

            section(
                title: Localizer.t("常用文件 / 文件夹", "Files & Folders"),
                addTitle: Localizer.t("添加文件", "Add File"),
                items: store.files,
                placeholder: Localizer.t("还没有文件，点击右上角“添加文件”", "No files yet. Click “Add File” above."),
                addAction: { showAddFile = true }
            )

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 680)
        .onChange(of: hotKeyEnabled) { _ in
            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        }
        .onAppear {
            reloadSystemShortcuts()
        }
        .onDisappear {
            HotKeyManager.shared.cancelRecording()
            recordingTarget = nil
        }
        .sheet(isPresented: $showAddURL) {
            ItemFormView(type: .url) { name, value, steps in
                store.add(QuickAction(name: name, type: .url, value: value, preCommands: steps))
            }
        }
        .sheet(isPresented: $showAddApp) {
            ItemFormView(type: .app) { name, value, steps in
                store.add(QuickAction(name: name, type: .app, value: value, preCommands: steps))
            }
        }
        .sheet(isPresented: $showAddFile) {
            ItemFormView(type: .file) { name, value, steps in
                store.add(QuickAction(name: name, type: .file, value: value, preCommands: steps))
            }
        }
        .sheet(item: $editingItem) { item in
            ItemFormView(type: item.type, existing: item) { name, value, steps in
                var updated = item
                updated.name = name
                updated.value = value
                updated.preCommands = steps
                store.update(updated)
            }
        }
    }

    private func startRecording(_ target: ShortcutRecordingTarget) {
        if recordingTarget == target {
            HotKeyManager.shared.cancelRecording()
            recordingTarget = nil
            return
        }
        recordingTarget = target
        HotKeyManager.shared.startRecording(
            onDone: { [self] keyCode, mods in
                switch target {
                case .globalHotkey:
                    HotKeyManager.save(keyCode: keyCode, modifiers: mods)
                case .menuSettings:
                    MenuShortcutSettings.save(kind: .settings, keyCode: keyCode, modifiers: mods)
                case .menuQuit:
                    MenuShortcutSettings.save(kind: .quit, keyCode: keyCode, modifiers: mods)
                }
                NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                recordingTarget = nil
            },
            onCancel: {
                recordingTarget = nil
            }
        )
    }

    private func reloadSystemShortcuts() {
        systemShortcuts = SystemAppShortcuts.all
    }

    /// 单行快捷键展示：名称 + 快捷键徽章 + 修改/恢复默认
    private func shortcutRow(title: String, description: String, isRecording: Bool, target: ShortcutRecordingTarget, kind: MenuShortcutKind) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            if isRecording {
                Text(Localizer.t("按下组合键…（Esc 取消）", "Press combination… (Esc to cancel)"))
                    .foregroundColor(.accentColor)
            } else {
                shortcutBadge(description)
            }
            Button(Localizer.t("修改", "Change")) { startRecording(target) }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(Localizer.t("默认", "Reset")) {
                MenuShortcutSettings.reset(kind: kind)
                NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(MenuShortcutSettings.isDefault(kind: kind))
        }
    }

    /// 快捷键徽章样式
    private func shortcutBadge(_ text: String) -> some View {
        Text(text.isEmpty ? Localizer.t("无", "None") : text)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func section(title: String, addTitle: String, items: [QuickAction], placeholder: String, addAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(addTitle, action: addAction)
            }

            if items.isEmpty {
                Text(placeholder)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                }
                .frame(maxHeight: 210)
            }
        }
    }

    private func row(_ item: QuickAction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol(for: item.type))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body).lineLimit(1)
                Text(item.value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.preCommands.isEmpty {
                    Label(commandSummary(item.preCommands), systemImage: "terminal")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button {
                editingItem = item
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button {
                store.move(item, by: -1, in: item.type)
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(isFirst(item))
            .buttonStyle(.borderless)

            Button {
                store.move(item, by: 1, in: item.type)
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(isLast(item))
            .buttonStyle(.borderless)

            Button(role: .destructive) {
                store.remove(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func isFirst(_ item: QuickAction) -> Bool {
        let list = store.items(of: item.type)
        return list.first?.id == item.id
    }

    private func isLast(_ item: QuickAction) -> Bool {
        let list = store.items(of: item.type)
        return list.last?.id == item.id
    }

    private func symbol(for type: QuickActionType) -> String {
        switch type {
        case .url: return "globe"
        case .app: return "app.dashed"
        case .file: return "folder"
        }
    }

    /// 把多条命令步骤汇总成一行摘要
    private func commandSummary(_ steps: [PreCommandStep]) -> String {
        steps.enumerated().map { idx, step in
            let cmd = step.command.trimmingCharacters(in: .whitespacesAndNewlines)
            let delayText = step.delayAfter > 0 ? Localizer.t("（等 \(delayString(step.delayAfter)) 秒）", " (wait \(delayString(step.delayAfter))s)") : ""
            return "\(idx + 1). \(cmd)\(delayText)"
        }.joined(separator: Localizer.t("  →  ", "  →  "))
    }

    /// 把秒数格式化成可读文本（整数不带小数，非整数保留 1 位）
    private func delayString(_ seconds: Double) -> String {
        seconds == seconds.rounded() ? String(Int(seconds)) : String(format: "%.1f", seconds)
    }
}

/// 添加 / 编辑快捷项的弹窗表单
struct ItemFormView: View {
    let type: QuickActionType
    /// 传 nil 表示新增，否则为编辑已有项
    let existing: QuickAction?
    let onSave: (String, String, [PreCommandStep]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlValue: String
    @State private var appPath: String
    @State private var filePath: String
    @State private var preSteps: [PreCommandStep]

    init(type: QuickActionType, existing: QuickAction? = nil, onSave: @escaping (String, String, [PreCommandStep]) -> Void) {
        self.type = type
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _preSteps = State(initialValue: existing?.preCommands ?? [])
        switch type {
        case .url:
            _urlValue = State(initialValue: existing?.value ?? "")
            _appPath = State(initialValue: "")
            _filePath = State(initialValue: "")
        case .app:
            _appPath = State(initialValue: existing?.value ?? "")
            _urlValue = State(initialValue: "")
            _filePath = State(initialValue: "")
        case .file:
            _filePath = State(initialValue: existing?.value ?? "")
            _urlValue = State(initialValue: "")
            _appPath = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            TextField(Localizer.t("显示名称（菜单中显示的名字）", "Display name (shown in menu)"), text: $name)
                .textFieldStyle(.roundedBorder)

            switch type {
            case .url:
                TextField(Localizer.t("网址，如 www.example.com", "URL, e.g. www.example.com"), text: $urlValue)
                    .textFieldStyle(.roundedBorder)
            case .app:
                HStack(spacing: 8) {
                    TextField(appPath.isEmpty ? Localizer.t("未选择", "Not selected") : appPath, text: $appPath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button(Localizer.t("选择 App…", "Choose App…")) { chooseApp() }
                }
            case .file:
                HStack(spacing: 8) {
                    TextField(filePath.isEmpty ? Localizer.t("未选择", "Not selected") : filePath, text: $filePath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button(Localizer.t("选择文件或文件夹…", "Choose File or Folder…")) { chooseFile() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(Localizer.t("打开前依次执行的命令（可选）", "Commands to run before opening (optional)"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if preSteps.isEmpty {
                    Text(Localizer.t("暂无命令，可添加多条命令并设置每条执行后的等待间隔。", "No commands yet. Add multiple commands to run in order, each with its own wait interval."))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(preSteps.indices, id: \.self) { idx in
                        stepRow(idx)
                    }
                }

                Button {
                    addStep()
                } label: {
                    Label(Localizer.t("添加命令", "Add Command"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.regular)
            }

            HStack {
                Spacer()
                Button(Localizer.t("取消", "Cancel")) { dismiss() }
                Button(Localizer.t("保存", "Save")) {
                    let value: String
                    switch type {
                    case .url: value = urlValue
                    case .app: value = appPath
                    case .file: value = filePath
                    }
                    let steps = preSteps
                        .map { PreCommandStep(command: $0.command.trimmingCharacters(in: .whitespacesAndNewlines), delayAfter: $0.delayAfter) }
                        .filter { !$0.command.isEmpty }
                    onSave(name, value, steps)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var title: String {
        if let existing = existing {
            return Localizer.t("编辑“\(existing.name)”", "Edit “\(existing.name)”")
        }
        switch type {
        case .url: return Localizer.t("添加网址", "Add Website")
        case .app: return Localizer.t("添加 App", "Add App")
        case .file: return Localizer.t("添加文件", "Add File")
        }
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch type {
        case .url: return !urlValue.trimmingCharacters(in: .whitespaces).isEmpty
        case .app: return !appPath.isEmpty
        case .file: return !filePath.isEmpty
        }
    }

    /// 单个命令步骤编辑行：命令输入框 + 执行后等待间隔 + 删除按钮
    private func stepRow(_ idx: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(idx + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .trailing)
                TextField(Localizer.t("命令，如 open https://example.com", "Command, e.g. open https://example.com"), text: stepCommandBinding(idx), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .font(.system(.caption))
                Button {
                    preSteps.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .disabled(preSteps.count == 1)
            }

            HStack(spacing: 6) {
                Text(Localizer.t("执行后等待", "Wait after run"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("0", value: stepDelayBinding(idx), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                Text(Localizer.t("秒（再执行下一条 / 打开目标）", "s (then next command / open target)"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 24)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
    }

    /// 命令文本的 Binding（按 index 读写 preSteps）
    private func stepCommandBinding(_ idx: Int) -> Binding<String> {
        Binding(
            get: { idx < preSteps.count ? preSteps[idx].command : "" },
            set: { newValue in
                if idx < preSteps.count {
                    preSteps[idx].command = newValue
                }
            }
        )
    }

    /// 等待间隔的 Binding
    private func stepDelayBinding(_ idx: Int) -> Binding<Double> {
        Binding(
            get: { idx < preSteps.count ? preSteps[idx].delayAfter : 0 },
            set: { newValue in
                if idx < preSteps.count {
                    preSteps[idx].delayAfter = max(0, newValue)
                }
            }
        )
    }

    private func addStep() {
        preSteps.append(PreCommandStep(command: ""))
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.appPath = url.path
            if self.name.trimmingCharacters(in: .whitespaces).isEmpty {
                self.name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.prompt = Localizer.t("选择", "Choose")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.filePath = url.path
            if self.name.trimmingCharacters(in: .whitespaces).isEmpty {
                self.name = url.lastPathComponent
            }
        }
    }
}

/// 可录制的快捷键目标
enum ShortcutRecordingTarget {
    case globalHotkey   // 全局呼出菜单
    case menuSettings   // 菜单"设置…"
    case menuQuit       // 菜单"退出"
}
