import Foundation

enum Environment {
    enum Server {
        case development
        case production
    }
    
    static var current: Server {
        if ProcessInfo.processInfo.environment["USE_PRODUCTION_API"] == "YES" {
            return .production
        }
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    static var baseURL: String {
        switch current {
        case .development:
//            return "http://localhost"
            return "https://9c7b41739b5d.ngrok-free.app"
//            return "http://192.168.127.49"
//            return "http://172.20.10.2"
        case .production:
            return "https://api.varink.com"
        }
    }
}
