import Foundation

protocol SupabaseServicing {
    func database(from table: String) -> DatabaseQueryBuilder
    func fetch<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> [T]
    func upsert<T: Encodable>(_ path: String, payload: T) async throws
    func signIn(email: String, password: String) async throws -> SessionToken
}

enum SupabaseError: Error {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case missingConfiguration
}

final class SupabaseService: SupabaseServicing {
    static let shared = SupabaseService()

    private let session: URLSession
    private let config: SupabaseConfig

    init(session: URLSession = .shared, config: SupabaseConfig = .current) {
        self.session = session
        self.config = config
    }

    func database(from table: String) -> DatabaseQueryBuilder {
        DatabaseQueryBuilder(table: table, config: config, session: session)
    }

    func signIn(email: String, password: String) async throws -> SessionToken {
        guard config.anonKey != "DEV_PLACEHOLDER_KEY" else { throw SupabaseError.missingConfiguration }
        let url = config.url.appending(path: "auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        guard let requestURL = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        return SessionToken(accessToken: authResponse.accessToken, refreshToken: authResponse.refreshToken, userID: authResponse.user.id)
    }

    func fetch<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> [T] {
        let endpoint = config.url.appending(path: "rest/v1").appendingPathComponent(path)
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        return try JSONDecoder.supabase.decode([T].self, from: data)
    }

    func upsert<T: Encodable>(_ path: String, payload: T) async throws {
        let url = config.url.appending(path: "rest/v1").appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.supabase.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        let accessToken = (try? KeychainStore.shared.readSession()?.accessToken) ?? config.anonKey
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
}

private struct AuthResponse: Codable {
    struct User: Codable { let id: UUID }
    let accessToken: String
    let refreshToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
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
        let profiles: [UserProfile] = try await database(from: "profiles")
            .select("id,full_name,email,role")
            .eq("id", userId.uuidString)
            .limit(1)
            .execute()

        return profiles.first ?? UserProfile(id: userId, fullName: "Inspector", email: "", role: "inspector")
    }
}
