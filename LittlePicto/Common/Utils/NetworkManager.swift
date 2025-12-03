import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingFailed
}

class NetworkManager {
    static let shared = NetworkManager()
    
    func request<T: Decodable>(
        urlString: String,
        responseType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NetworkError.noData))
                return
            }
          
            do {
                let decoded = try JSONDecoder().decode(responseType, from: data)
//                print(decoded)
                completion(.success(decoded))
            } catch {
                print("❌ 解码失败: \(error)")
                print("原始数据: \(String(data: data, encoding: .utf8) ?? "无效")")
                completion(.failure(NetworkError.decodingFailed))
            }
        }.resume()
    }
}
