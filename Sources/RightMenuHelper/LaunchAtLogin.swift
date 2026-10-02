import Foundation
import ServiceManagement

/// 开机自启动管理（macOS 13+，基于 SMAppService）
/// 默认关闭；开关状态持久化到 UserDefaults
enum LaunchAtLogin {
    static let preferenceKey = "launchAtLogin"

    /// 当前是否开启开机自启动
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: preferenceKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: preferenceKey)
            apply(newValue)
        }
    }

    /// 让配置立即生效（注册/注销登录项）
    static func apply() {
        apply(isEnabled)
    }

    private static func apply(_ enable: Bool) {
        if enable {
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSLog("FastLaunch: 注册登录项失败 - \(error)")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                NSLog("FastLaunch: 注销登录项失败 - \(error)")
            }
        }
    }
}
