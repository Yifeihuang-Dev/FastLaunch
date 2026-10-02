import AppKit
import Carbon.HIToolbox

/// 应用内菜单项快捷键（"设置…" / "退出"）的配置存取，支持用户录制修改。
enum MenuShortcutKind: String, CaseIterable {
    case settings
    case quit

    var prefKey: String {
        switch self {
        case .settings: return "menuShortcutSettings"
        case .quit: return "menuShortcutQuit"
        }
    }

    /// 默认快捷键
    var defaultKeyCode: UInt32 {
        switch self {
        case .settings: return UInt32(kVK_ANSI_Comma) // ⌘,
        case .quit: return UInt32(kVK_ANSI_Q)         // ⌘Q
        }
    }

    var defaultModifiers: UInt32 {
        UInt32(cmdKey)
    }
}

/// 菜单快捷键存取与 NSMenuItem keyEquivalent 互转
enum MenuShortcutSettings {
    static func keyCode(for kind: MenuShortcutKind) -> UInt32 {
        let d = UserDefaults.standard
        return d.object(forKey: kind.prefKey + "Code") == nil
            ? kind.defaultKeyCode
            : UInt32(d.integer(forKey: kind.prefKey + "Code"))
    }

    static func modifiers(for kind: MenuShortcutKind) -> UInt32 {
        let d = UserDefaults.standard
        return d.object(forKey: kind.prefKey + "Mods") == nil
            ? kind.defaultModifiers
            : UInt32(d.integer(forKey: kind.prefKey + "Mods"))
    }

    static func save(kind: MenuShortcutKind, keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: kind.prefKey + "Code")
        UserDefaults.standard.set(Int(modifiers), forKey: kind.prefKey + "Mods")
    }

    static func reset(kind: MenuShortcutKind) {
        UserDefaults.standard.removeObject(forKey: kind.prefKey + "Code")
        UserDefaults.standard.removeObject(forKey: kind.prefKey + "Mods")
    }

    /// 显示文本（如 ⌘,）
    static func description(kind: MenuShortcutKind) -> String {
        HotKeyManager.description(keyCode: keyCode(for: kind), modifiers: modifiers(for: kind))
    }

    /// 是否等于默认值（用于"恢复默认"按钮状态）
    static func isDefault(kind: MenuShortcutKind) -> Bool {
        keyCode(for: kind) == kind.defaultKeyCode && modifiers(for: kind) == kind.defaultModifiers
    }

    // MARK: - 转换

    /// keyCode → NSMenuItem.keyEquivalent 字符串（字母小写、数字符号原样、特殊键转控制字符）
    static func keyEquivalent(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case Int(kVK_Return): return "\r"
        case Int(kVK_Tab): return "\t"
        case Int(kVK_Space): return " "
        case Int(kVK_Delete): return "\u{7f}"
        case Int(kVK_ForwardDelete): return "\u{F728}"
        case Int(kVK_Escape): return "\u{1b}"
        case Int(kVK_Home): return "\u{F729}"
        case Int(kVK_End): return "\u{F72B}"
        case Int(kVK_PageUp): return "\u{F72C}"
        case Int(kVK_PageDown): return "\u{F72D}"
        case Int(kVK_UpArrow): return "\u{F700}"
        case Int(kVK_DownArrow): return "\u{F701}"
        case Int(kVK_LeftArrow): return "\u{F702}"
        case Int(kVK_RightArrow): return "\u{F703}"
        default: return Self.singleChar(for: keyCode)
        }
    }

    /// carbon 修饰键掩码 → NSEvent.ModifierFlags
    static func modifierMask(for modifiers: UInt32) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        return mask
    }

    /// 单字符键（字母/数字/符号）→ 小写字母或原字符
    private static func singleChar(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case Int(kVK_ANSI_A): return "a"
        case Int(kVK_ANSI_S): return "s"
        case Int(kVK_ANSI_D): return "d"
        case Int(kVK_ANSI_F): return "f"
        case Int(kVK_ANSI_H): return "h"
        case Int(kVK_ANSI_G): return "g"
        case Int(kVK_ANSI_Z): return "z"
        case Int(kVK_ANSI_X): return "x"
        case Int(kVK_ANSI_C): return "c"
        case Int(kVK_ANSI_V): return "v"
        case Int(kVK_ANSI_B): return "b"
        case Int(kVK_ANSI_Q): return "q"
        case Int(kVK_ANSI_W): return "w"
        case Int(kVK_ANSI_E): return "e"
        case Int(kVK_ANSI_R): return "r"
        case Int(kVK_ANSI_Y): return "y"
        case Int(kVK_ANSI_T): return "t"
        case Int(kVK_ANSI_O): return "o"
        case Int(kVK_ANSI_U): return "u"
        case Int(kVK_ANSI_I): return "i"
        case Int(kVK_ANSI_P): return "p"
        case Int(kVK_ANSI_L): return "l"
        case Int(kVK_ANSI_J): return "j"
        case Int(kVK_ANSI_K): return "k"
        case Int(kVK_ANSI_N): return "n"
        case Int(kVK_ANSI_M): return "m"
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
        default: return ""
        }
    }
}

/// 系统 App 快捷键：用户在 macOS「系统设置 → 键盘 → 键盘快捷键 → App 快捷键」中为 FastLaunch 添加的快捷键。
/// 存储在全局偏好 `NSUserKeyEquivalents`（外层按应用名分组）。
struct SystemAppShortcut: Identifiable {
    let menuTitle: String
    let keyString: String
    var id: String { menuTitle }
}

enum SystemAppShortcuts {
    /// 分组键：对应应用名（CFBundleName）
    static let appKey = "FastLaunch"

    /// 读取所有为 FastLaunch 添加的系统 App 快捷键
    static var all: [SystemAppShortcut] {
        guard let dict = UserDefaults.standard.dictionary(forKey: "NSUserKeyEquivalents") as? [String: [String: String]],
              let map = dict[appKey] else { return [] }
        return map
            .map { SystemAppShortcut(menuTitle: $0.key, keyString: $0.value) }
            .sorted { $0.menuTitle.localizedStandardCompare($1.menuTitle) == .orderedAscending }
    }

    /// 删除一条（同时写回全局偏好，系统设置可感知）
    static func remove(menuTitle: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: "NSUserKeyEquivalents") as? [String: [String: String]]) ?? [:]
        var map = dict[appKey] ?? [:]
        map.removeValue(forKey: menuTitle)
        if map.isEmpty {
            dict.removeValue(forKey: appKey)
        } else {
            dict[appKey] = map
        }
        UserDefaults.standard.set(dict, forKey: "NSUserKeyEquivalents")
        UserDefaults.standard.synchronize()
    }

    /// 把系统编码（如 "@^m"）转成可读文本（⌘⌃M）
    static func displayText(for keyString: String) -> String {
        var parts: [String] = []
        var main = ""
        for ch in keyString {
            switch ch {
            case "^": parts.append("⌃")
            case "~": parts.append("⌥")
            case "$": parts.append("⇧")
            case "@": parts.append("⌘")
            default: main.append(ch)
            }
        }
        if main.isEmpty { main = "?" }

        let mainName: String
        if let scalar = main.unicodeScalars.first {
            switch scalar.value {
            case 0xF700: mainName = "↑"
            case 0xF701: mainName = "↓"
            case 0xF702: mainName = "←"
            case 0xF703: mainName = "→"
            case 0xF728: mainName = "⌦"
            case 0xF729: mainName = "Home"
            case 0xF72B: mainName = "End"
            case 0xF72C: mainName = "PgUp"
            case 0xF72D: mainName = "PgDn"
            case 0x0D: mainName = "Return"
            case 0x09: mainName = "Tab"
            case 0x20: mainName = "Space"
            default: mainName = main.uppercased()
            }
        } else {
            mainName = main.uppercased()
        }
        return (parts + [mainName]).joined()
    }
}
