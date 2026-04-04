import Foundation

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://health-care-bot-production.up.railway.app"

    func sendHealthData(_ data: HealthData, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONEncoder().encode(data)
        } catch {
            completion(.failure(error)); return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let err = NSError(domain: "APIClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
                completion(.failure(err)); return
            }
            completion(.success(()))
        }.resume()
    }
}
