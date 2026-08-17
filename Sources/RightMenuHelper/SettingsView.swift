import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: ActionStore
    @AppStorage(Localizer.preferenceKey) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(HotKeyManager.enabledPrefKey) private var hotKeyEnabled = true
    @State private var showAddURL = false
    @State private var showAddApp = false
    @State private var editingItem: QuickAction?
    @State private var recording = false

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

            Divider()

            // 全局快捷键
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle(Localizer.t("全局快捷键（任意界面呼出菜单）", "Global hotkey (open menu anywhere)"), isOn: $hotKeyEnabled)
                    Spacer()
                    if hotKeyEnabled && !recording {
                        Text(HotKeyManager.description(keyCode: HotKeyManager.storedKeyCode, modifiers: HotKeyManager.storedModifiers))
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
                if hotKeyEnabled {
                    HStack(spacing: 8) {
                        Button(recording ? Localizer.t("按下组合键…（Esc 取消）", "Press combination… (Esc to cancel)") : Localizer.t("修改快捷键", "Change Hotkey")) {
                            toggleRecording()
                        }
                        .buttonStyle(.bordered)

                        Text(Localizer.t("需包含 ⌘ ⌥ ⌃ ⇧ 中至少一个修饰键", "Must include at least one modifier key (⌘ ⌥ ⌃ ⇧)"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 680)
        .onChange(of: hotKeyEnabled) { _ in
            NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        }
        .onDisappear {
            HotKeyManager.shared.cancelRecording()
            recording = false
        }
        .sheet(isPresented: $showAddURL) {
            ItemFormView(type: .url) { name, value, cmd in
                store.add(QuickAction(name: name, type: .url, value: value, preCommand: cmd))
            }
        }
        .sheet(isPresented: $showAddApp) {
            ItemFormView(type: .app) { name, value, cmd in
                store.add(QuickAction(name: name, type: .app, value: value, preCommand: cmd))
            }
        }
        .sheet(item: $editingItem) { item in
            ItemFormView(type: item.type, existing: item) { name, value, cmd in
                var updated = item
                updated.name = name
                updated.value = value
                updated.preCommand = cmd
                store.update(updated)
            }
        }
    }

    private func toggleRecording() {
        if recording {
            HotKeyManager.shared.cancelRecording()
            recording = false
        } else {
            recording = true
            HotKeyManager.shared.startRecording(
                onDone: { [self] keyCode, mods in
                    HotKeyManager.save(keyCode: keyCode, modifiers: mods)
                    NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
                    recording = false
                },
                onCancel: {
                    recording = false
                }
            )
        }
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
            Image(systemName: item.type == .url ? "globe" : "app.dashed")
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body).lineLimit(1)
                Text(item.value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let cmd = item.preCommand, !cmd.isEmpty {
                    Label(cmd, systemImage: "terminal")
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
        let list = item.type == .url ? store.urls : store.apps
        return list.first?.id == item.id
    }

    private func isLast(_ item: QuickAction) -> Bool {
        let list = item.type == .url ? store.urls : store.apps
        return list.last?.id == item.id
    }
}

/// 添加 / 编辑快捷项的弹窗表单
struct ItemFormView: View {
    let type: QuickActionType
    /// 传 nil 表示新增，否则为编辑已有项
    let existing: QuickAction?
    let onSave: (String, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlValue: String
    @State private var appPath: String
    @State private var preCommand: String

    init(type: QuickActionType, existing: QuickAction? = nil, onSave: @escaping (String, String, String?) -> Void) {
        self.type = type
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _preCommand = State(initialValue: existing?.preCommand ?? "")
        if type == .app {
            _appPath = State(initialValue: existing?.value ?? "")
            _urlValue = State(initialValue: "")
        } else {
            _urlValue = State(initialValue: existing?.value ?? "")
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
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Localizer.t("打开前的操作（可选）", "Pre-action before opening (optional)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(Localizer.t("如先开启某设置：open x-apple.systempreferences:com.apple.preference.general", "e.g. open x-apple.systempreferences:com.apple.preference.general"), text: $preCommand, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            HStack {
                Spacer()
                Button(Localizer.t("取消", "Cancel")) { dismiss() }
                Button(Localizer.t("保存", "Save")) {
                    let value = type == .url ? urlValue : appPath
                    let cmd = preCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(name, value, cmd.isEmpty ? nil : cmd)
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
        return type == .url
            ? Localizer.t("添加网址", "Add Website")
            : Localizer.t("添加 App", "Add App")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (type == .url
                ? !urlValue.trimmingCharacters(in: .whitespaces).isEmpty
                : !appPath.isEmpty)
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
}
