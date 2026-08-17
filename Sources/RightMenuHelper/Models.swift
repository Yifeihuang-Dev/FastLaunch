import Foundation

/// 快捷项类型：网址 或 App
enum QuickActionType: String, Codable, CaseIterable {
    case url
    case app

    var displayName: String {
        switch self {
        case .url: return "网址"
        case .app: return "App"
        }
    }
}

/// 一条用户自定义的快捷项
struct QuickAction: Identifiable, Codable, Equatable {
    var id = UUID()
    /// 菜单中显示的名称（用户自定义）
    var name: String
    var type: QuickActionType
    /// type == .url 时为网址字符串；type == .app 时为 .app 的完整路径
    var value: String
    /// 可选的打开前置操作：一条 shell 命令，执行完成后再打开 value
    var preCommand: String?
}
