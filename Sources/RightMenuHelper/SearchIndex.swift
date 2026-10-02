import Foundation

/// 轻量搜索索引：对快捷项的名称与路径做一次小写化预计算，
/// 搜索时无需重复调用 `lowercased()`，并用优先级排序让最相关结果排在最前。
struct SearchIndex {
    /// 预计算条目：缓存小写化后的可检索文本，避免搜索时重复转换
    private struct Entry {
        let action: QuickAction
        let lowerName: String
        let lowerValue: String
    }

    private var entries: [Entry] = []

    /// 重建索引。应在数据变更时调用（量小，直接全量重建即可）。
    mutating func rebuild(with actions: [QuickAction]) {
        entries = actions.map {
            Entry(
                action: $0,
                lowerName: $0.name.lowercased(),
                lowerValue: $0.value.lowercased()
            )
        }
    }

    /// 返回当前已索引的条目数
    var count: Int { entries.count }

    /// 搜索：按匹配质量排序，返回命中的快捷项。
    /// - Parameter query: 原始（未转小写）查询词
    /// - Returns: 排序后的命中结果（按类型分组，组内按相关度降序）
    func search(_ query: String) -> [QuickAction] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries.map(\.action) }
        let q = trimmed.lowercased()
        let tokens = q.split(whereSeparator: { $0.isWhitespace })

        var results: [(action: QuickAction, score: Int)] = []
        results.reserveCapacity(entries.count)

        for entry in entries {
            // 命中的 token 数量：命中越多越靠前
            let hitTokens = tokens.filter { token in
                entry.lowerName.contains(token) || entry.lowerValue.contains(token)
            }
            guard !hitTokens.isEmpty else { continue }

            // 相关度评分：名称前缀命中权重最高
            var score = 0
            let nameHit = entry.lowerName.contains(q)
            if nameHit { score += 20 }
            if entry.lowerName.hasPrefix(q) { score += 50 }
            if entry.lowerValue.hasPrefix(q) { score += 10 }
            score += hitTokens.count * 5
            // 名称比路径更相关
            if entry.lowerName.contains(q) { score += 5 }

            results.append((entry.action, score))
        }

        // 按相关度降序、再按名称字母序稳定排序；最后按类型分组
        results.sort { ($0.score, $0.action.name.lowercased()) > ($1.score, $1.action.name.lowercased()) }
        return results.map(\.action)
    }
}
