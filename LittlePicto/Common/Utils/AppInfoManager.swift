import Foundation

class AppInfoManager {
    
    static let shared = AppInfoManager()
    
    private init() {}
    
    /// 获取 App 的显示名称
    var appName: String {
        if let displayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        } else if let name = Bundle.main.infoDictionary?["CFBundleName"] as? String {
            return name
        } else {
            return "未知App"
        }
    }
    
    /// 获取 App 的版本号（例如：1.0.0）
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知版本"
    }
    
    /// 获取 App 的 Build 号（例如：100）
    var appBuild: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知Build"
    }
}
