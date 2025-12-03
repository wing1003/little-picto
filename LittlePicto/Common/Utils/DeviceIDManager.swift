import Foundation

final class DeviceIDManager {
    static let shared = DeviceIDManager()
    
    private let uuidKey = "com.pausehere.deviceUUID"
    private(set) var deviceUUID: String

    private init() {
        if let savedUUID = UserDefaults.standard.string(forKey: uuidKey) {
            deviceUUID = savedUUID
        } else {
            let newUUID = UUID().uuidString
            UserDefaults.standard.set(newUUID, forKey: uuidKey)
            deviceUUID = newUUID
        }
    }
    
    /// Only for testing
    func resetUUID() {
        UserDefaults.standard.removeObject(forKey: uuidKey)
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: uuidKey)
        deviceUUID = newUUID
    }
}
