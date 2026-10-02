import Foundation
import Combine

/// 配置存储：负责快捷项的增删改、排序与本地持久化
final class ActionStore: ObservableObject {
    @Published var actions: [QuickAction] = [] {
        didSet { save() }
    }

    private static let storageKey = "quickActions.v1"

    init() {
        load()
    }

    var urls: [QuickAction] { actions.filter { $0.type == .url } }
    var apps: [QuickAction] { actions.filter { $0.type == .app } }
    var files: [QuickAction] { actions.filter { $0.type == .file } }

    func items(of type: QuickActionType) -> [QuickAction] {
        switch type {
        case .url: return urls
        case .app: return apps
        case .file: return files
        }
    }

    func add(_ action: QuickAction) {
        actions.append(action)
    }

    func remove(_ action: QuickAction) {
        actions.removeAll { $0.id == action.id }
    }

    func update(_ action: QuickAction) {
        guard let idx = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[idx] = action
    }

    /// 在同类型列表中上移/下移一项
    func move(_ action: QuickAction, by offset: Int, in type: QuickActionType) {
        let list = items(of: type)
        guard let from = list.firstIndex(where: { $0.id == action.id }) else { return }
        let to = from + offset
        guard to >= 0 && to < list.count else { return }

        var newList = list
        newList.remove(at: from)
        newList.insert(action, at: to)
        actions = actions.filter { $0.type != type } + newList
    }

    // MARK: - 持久化

    private func save() {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let items = try? JSONDecoder().decode([QuickAction].self, from: data) else {
            return
        }
        actions = items
    }
}
