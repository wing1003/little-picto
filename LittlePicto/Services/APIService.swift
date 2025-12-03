import Foundation
import UIKit

class APIService {
    static let shared = APIService()
    
    private init() {}
    
    /// 扫码注册（POST请求）
    func register(code: String, sig: String, completion: @escaping (Result<CheckUdidResponse, Error>) -> Void) {
        guard let url = URL(string: "\(Environment.baseURL)/api/auth/register") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let deviceInfo = UIDevice.current.model + " / " + UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let deviceId = DeviceIDManager.shared.deviceUUID;
        let body: [String: Any] = [
            "uuid": deviceId,
            "code": code,
            "sig": sig,
            "device_info": deviceInfo,
            "app_version": appVersion
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(CheckUdidResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                print("❌ 解码失败: \(error)")
                print("原始数据: \(String(data: data, encoding: .utf8) ?? "无效")")
                completion(.failure(NetworkError.decodingFailed))
            }
        }.resume()
    }
    
    struct CheckUdidResponse: Codable {
        let code: Int
        let message: String
        let data: CheckUdidData
    }
    
    struct CheckUdidData: Codable {
        let success: Bool
        let errors: CheckUdidErrors?
    }
    
    struct CheckUdidErrors: Codable {
        let uuid: [String]?
    }

    func uploadImage(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(Environment.baseURL)/api/upload") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            completion(.failure(NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create JPEG data."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let uploadError = NSError(
                    domain: "Upload",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Upload failed with status code \(statusCode)"]
                )
                completion(.failure(uploadError))
            }
        }.resume()
    }
    func checkUdid(
        deviceId: String,
        completion: @escaping (Result<CheckUdidResponse, Error>) -> Void
    ) {
        let urlString = "\(Environment.baseURL)/api/auth/check-uuid"
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "uuid", value: deviceId)
        ]
        
        guard let finalURL = components.url else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        NetworkManager.shared.request(
            urlString: finalURL.absoluteString,
            responseType: CheckUdidResponse.self,
            completion: completion
        )
    }
}
