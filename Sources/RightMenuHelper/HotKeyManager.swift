import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    /// 快捷键配置变化（启用开关 / 录制新组合）时发出
    static let hotKeyDidChange = Notification.Name("FastLaunch.hotKeyDidChange")
}

/// 全局快捷键管理器（基于 Carbon RegisterEventHotKey，无第三方依赖）
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// 触发回调（保证在主线程执行）
    var onHotKey: (() -> Void)?

    static let keyCodePrefKey = "hotKeyKeyCode"
    static let modifiersPrefKey = "hotKeyModifiers"
    static let enabledPrefKey = "hotKeyEnabled"

    /// 默认快捷键：⌥⌘L
    static let defaultKeyCode: UInt32 = UInt32(kVK_ANSI_L)
    static let defaultModifiers: UInt32 = UInt32(cmdKey) | UInt32(optionKey)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: 0x46415354, id: 1) // "FAST"

    private var recorderMonitor: Any?
    private var recorderDone: ((UInt32, UInt32) -> Void)?
    private var recorderCancel: (() -> Void)?

    var isRegistered: Bool { hotKeyRef != nil }

    // MARK: - 注册 / 注销

    /// 注册全局快捷键，成功返回 true
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onHotKey?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
        guard handlerStatus == noErr else { return false }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else {
            RemoveEventHandler(eventHandlerRef)
            eventHandlerRef = nil
            return false
        }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
            eventHandlerRef = nil
        }
    }

    deinit { unregister() }

    // MARK: - 配置存取

    static var storedKeyCode: UInt32 {
        let d = UserDefaults.standard
        return d.object(forKey: keyCodePrefKey) == nil ? defaultKeyCode : UInt32(d.integer(forKey: keyCodePrefKey))
    }

    static var storedModifiers: UInt32 {
        let d = UserDefaults.standard
        return d.object(forKey: modifiersPrefKey) == nil ? defaultModifiers : UInt32(d.integer(forKey: modifiersPrefKey))
    }

    static var isEnabled: Bool {
        get {
            let d = UserDefaults.standard
            return d.object(forKey: enabledPrefKey) == nil ? true : d.bool(forKey: enabledPrefKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledPrefKey) }
    }

    static func save(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: keyCodePrefKey)
        UserDefaults.standard.set(Int(modifiers), forKey: modifiersPrefKey)
    }

    // MARK: - 录制（在设置窗口中按下新组合键）

    func startRecording(onDone: @escaping (UInt32, UInt32) -> Void, onCancel: @escaping () -> Void) {
        cancelRecording()
        recorderDone = onDone
        recorderCancel = onCancel

        recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            // Esc 取消
            if event.keyCode == UInt32(kVK_Escape) {
                self.finishRecording()
                self.recorderCancel?()
                return event
            }

            // 修饰键单独按下忽略（等真正组合键）
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }
            // 排除本身是修饰键的键码
            let modifierKeyCodes: [UInt32] = [
                UInt32(kVK_Command), UInt32(kVK_Shift), UInt32(kVK_Option), UInt32(kVK_Control),
                UInt32(kVK_RightCommand), UInt32(kVK_RightShift), UInt32(kVK_RightOption), UInt32(kVK_RightControl),
                UInt32(kVK_CapsLock), UInt32(kVK_Function)
            ]
            guard !modifierKeyCodes.contains(UInt32(event.keyCode)) else { return event }

            let carbonMods = Self.carbonModifiers(from: mods)
            let keyCode = UInt32(event.keyCode)
            let done = self.recorderDone
            self.finishRecording()
            done?(keyCode, carbonMods)
            return nil
        }
    }

    func cancelRecording() {
        finishRecording()
        recorderDone = nil
        recorderCancel = nil
    }

    private func finishRecording() {
        if let m = recorderMonitor {
            NSEvent.removeMonitor(m)
            recorderMonitor = nil
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    // MARK: - 显示文本

    static func description(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        let mods = Int(modifiers)
        if mods & Int(controlKey) != 0 { parts.append("⌃") }
        if mods & Int(optionKey) != 0 { parts.append("⌥") }
        if mods & Int(shiftKey) != 0 { parts.append("⇧") }
        if mods & Int(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case Int(kVK_Space): return "Space"
        case Int(kVK_Return): return "Return"
        case Int(kVK_Tab): return "Tab"
        case Int(kVK_Delete): return "Delete"
        case Int(kVK_ForwardDelete): return "Fn+Delete"
        case Int(kVK_Escape): return "Esc"
        case Int(kVK_UpArrow): return "↑"
        case Int(kVK_DownArrow): return "↓"
        case Int(kVK_LeftArrow): return "←"
        case Int(kVK_RightArrow): return "→"
        case Int(kVK_Home): return "Home"
        case Int(kVK_End): return "End"
        case Int(kVK_PageUp): return "PgUp"
        case Int(kVK_PageDown): return "PgDn"
        case Int(kVK_ANSI_A): return "A"
        case Int(kVK_ANSI_S): return "S"
        case Int(kVK_ANSI_D): return "D"
        case Int(kVK_ANSI_F): return "F"
        case Int(kVK_ANSI_H): return "H"
        case Int(kVK_ANSI_G): return "G"
        case Int(kVK_ANSI_Z): return "Z"
        case Int(kVK_ANSI_X): return "X"
        case Int(kVK_ANSI_C): return "C"
        case Int(kVK_ANSI_V): return "V"
        case Int(kVK_ANSI_B): return "B"
        case Int(kVK_ANSI_Q): return "Q"
        case Int(kVK_ANSI_W): return "W"
        case Int(kVK_ANSI_E): return "E"
        case Int(kVK_ANSI_R): return "R"
        case Int(kVK_ANSI_Y): return "Y"
        case Int(kVK_ANSI_T): return "T"
        case Int(kVK_ANSI_O): return "O"
        case Int(kVK_ANSI_U): return "U"
        case Int(kVK_ANSI_I): return "I"
        case Int(kVK_ANSI_P): return "P"
        case Int(kVK_ANSI_L): return "L"
        case Int(kVK_ANSI_J): return "J"
        case Int(kVK_ANSI_K): return "K"
        case Int(kVK_ANSI_N): return "N"
        case Int(kVK_ANSI_M): return "M"
        case Int(kVK_ANSI_1): return "1"
        case Int(kVK_ANSI_2): return "2"
        case Int(kVK_ANSI_3): return "3"
        case Int(kVK_ANSI_4): return "4"
        case Int(kVK_ANSI_5): return "5"
        case Int(kVK_ANSI_6): return "6"
        case Int(kVK_ANSI_7): return "7"
        case Int(kVK_ANSI_8): return "8"
        case Int(kVK_ANSI_9): return "9"
        case Int(kVK_ANSI_0): return "0"
        case Int(kVK_ANSI_Minus): return "-"
        case Int(kVK_ANSI_Equal): return "="
        case Int(kVK_ANSI_LeftBracket): return "["
        case Int(kVK_ANSI_RightBracket): return "]"
        case Int(kVK_ANSI_Semicolon): return ";"
        case Int(kVK_ANSI_Quote): return "'"
        case Int(kVK_ANSI_Grave): return "`"
        case Int(kVK_ANSI_Backslash): return "\\"
        case Int(kVK_ANSI_Comma): return ","
        case Int(kVK_ANSI_Period): return "."
        case Int(kVK_ANSI_Slash): return "/"
        default: return "Key(\(keyCode))"
        }
    }
}
