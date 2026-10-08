import Foundation
import Security

struct PlacesClient: Sendable {
    static let defaultURL = "http://127.0.0.1:8787"
    let baseURL: String
    let token: String

    static func configured() -> PlacesClient {
        .init(baseURL: UserDefaults.standard.string(forKey: "bridgeURL") ?? defaultURL, token: BridgeCredential.read())
    }

    func search(_ query: String, latitude: Double, longitude: Double, radius: Double) async throws -> [Place] {
        let data = try await get("search", parameters: [
            "q": query,
            "latitude": String(latitude),
            "longitude": String(longitude),
            "radius": String(min(50_000, max(500, radius)))
        ])
        struct Results: Decodable { let places: [Place] }
        return try JSONDecoder().decode(Results.self, from: data).places.filter { $0.coordinate != nil }
    }

    func details(_ id: String) async throws -> Place {
        try await JSONDecoder().decode(Place.self, from: get("details", parameters: ["id": id]))
    }

    func photo(_ name: String) async throws -> Data {
        try await get("photo", parameters: ["name": name, "width": "1200"])
    }

    func health() async throws {
        _ = try await get("health")
    }

    private func get(_ path: String, parameters: [String: String] = [:]) async throws -> Data {
        guard let base = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(base.scheme?.lowercased() ?? ""), base.host != nil,
              var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw BridgeError.message("Enter a valid bridge URL in Search Connection.")
        }
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw BridgeError.message("The bridge URL is invalid.") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw BridgeError.message("Cannot reach the search bridge. Start Bridge/run.sh and check Search Connection.")
        }
        guard let http = response as? HTTPURLResponse else { throw BridgeError.message("Invalid bridge response.") }
        guard (200..<300).contains(http.statusCode) else {
            struct Failure: Decodable { let error: String }
            let message = (try? JSONDecoder().decode(Failure.self, from: data).error) ?? "Search bridge returned an error (\(http.statusCode))."
            throw BridgeError.message(message)
        }
        return data
    }
}

enum BridgeError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

enum BridgeCredential {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.stefan.private-maps.bridge",
         kSecAttrAccount as String: "access-token"]
    }

    static func read() -> String {
        var query = query
        query[kSecReturnData as String] = true
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func save(_ token: String) throws {
        if token.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw BridgeError.message("Could not remove the saved bridge token from Keychain.")
            }
            return
        }
        let attributes = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw BridgeError.message("Could not save the bridge token to Keychain (\(status)).")
        }
    }
}
