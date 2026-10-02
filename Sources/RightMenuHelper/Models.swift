import Foundation

/// 快捷项类型：网址 / App / 文件或文件夹
enum QuickActionType: String, Codable, CaseIterable {
    case url
    case app
    case file

    var displayName: String {
        switch self {
        case .url: return "网址"
        case .app: return "App"
        case .file: return "文件/文件夹"
        }
    }
}

/// 一条"打开前"执行的命令步骤
struct PreCommandStep: Codable, Equatable, Identifiable {
    var id = UUID()
    /// 要执行的 shell 命令
    var command: String
    /// 该命令执行完成后、进入下一步（或打开目标）前等待的秒数
    var delayAfter: Double = 0

    init(command: String, delayAfter: Double = 0) {
        self.command = command
        self.delayAfter = delayAfter
    }
}

/// 一条用户自定义的快捷项
struct QuickAction: Identifiable, Codable, Equatable {
    var id = UUID()
    /// 菜单中显示的名称（用户自定义）
    var name: String
    var type: QuickActionType
    /// type == .url 时为网址字符串；type == .app 时为 .app 的完整路径；type == .file 时为文件/文件夹的完整路径
    var value: String
    /// 打开前依次执行的命令步骤（可选），全部执行完并等待对应间隔后再打开 value
    var preCommands: [PreCommandStep]

    init(id: UUID = UUID(), name: String, type: QuickActionType, value: String, preCommands: [PreCommandStep]) {
        self.id = id
        self.name = name
        self.type = type
        self.value = value
        self.preCommands = preCommands
    }

    /// 是否有前置命令步骤
    var hasPreCommands: Bool {
        !preCommands.isEmpty
    }

    // MARK: - Codable（兼容旧版 preCommand 字符串字段）

    private enum CodingKeys: String, CodingKey {
        case id, name, type, value, preCommands, preCommand
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(QuickActionType.self, forKey: .type)
        value = try c.decode(String.self, forKey: .value)

        if let steps = try c.decodeIfPresent([PreCommandStep].self, forKey: .preCommands) {
            preCommands = steps
        } else if let single = try c.decodeIfPresent(String.self, forKey: .preCommand),
                  !single.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 旧版单条命令 → 迁移为一条步骤
            preCommands = [PreCommandStep(command: single)]
        } else {
            preCommands = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(type, forKey: .type)
        try c.encode(value, forKey: .value)
        try c.encode(preCommands, forKey: .preCommands)
    }
}
