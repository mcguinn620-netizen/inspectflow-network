import Foundation

protocol SupabaseServicing {
    func fetch<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> [T]
    func upsert<T: Encodable>(_ path: String, payload: T) async throws
}

enum SupabaseError: Error {
    case invalidURL
    case invalidResponse
    case serverError(Int)
}

final class SupabaseService: SupabaseServicing {
    static let shared = SupabaseService()

    private let session: URLSession
    private let config: SupabaseConfig

    init(session: URLSession = .shared, config: SupabaseConfig = .current) {
        self.session = session
        self.config = config
    }

    func fetch<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> [T] {
        var components = URLComponents(string: config.url.appending(path))
        components?.queryItems = queryItems
        guard let url = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw SupabaseError.serverError(httpResponse.statusCode) }

        return try JSONDecoder.supabase.decode([T].self, from: data)
    }

    func upsert<T: Encodable>(_ path: String, payload: T) async throws {
        guard let url = URL(string: config.url.appending(path)) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.supabase.encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else { throw SupabaseError.serverError(httpResponse.statusCode) }
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}


extension SupabaseService {
    func fetchMyProfile(userId: UUID) async throws -> UserProfile {
        let profiles: [UserProfile] = try await fetch("profiles", queryItems: [
            URLQueryItem(name: "id", value: "eq.\(userId.uuidString)"),
            URLQueryItem(name: "select", value: "id,full_name,email")
        ])
        return profiles.first ?? UserProfile(id: userId, fullName: "Inspector", email: "")
    }
}
