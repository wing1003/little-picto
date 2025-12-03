import Foundation

func ParseScanResult(_ scannedString: String) -> (code: String, sig: String)? {
    if scannedString.contains("http") {
        if let urlComponents = URLComponents(string: scannedString),
           let queryItems = urlComponents.queryItems {
            let code = queryItems.first(where: { $0.name == "code" })?.value
            let sig = queryItems.first(where: { $0.name == "sig" })?.value

            if let code = code, let sig = sig {
                return (code, sig)
            }
        }
    } else if scannedString.contains("|") {
        let parts = scannedString.split(separator: "|")
        if parts.count == 2 {
            let code = String(parts[0])
            let sig = String(parts[1])
            return (code, sig)
        }
    }

    // 解析失败
    return nil
}
