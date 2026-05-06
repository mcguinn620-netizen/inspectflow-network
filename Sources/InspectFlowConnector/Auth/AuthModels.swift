import Foundation

public struct InspectFlowUser: Codable, Identifiable, Equatable {
    public let id: UUID
    public let email: String?
    public let phone: String?
}

public struct InspectFlowSession: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let user: InspectFlowUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }

    public init(accessToken: String, refreshToken: String, expiresAt: Date, user: InspectFlowUser) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.user = user
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        // Supabase returns expires_at as unix seconds OR expires_in (relative)
        if let ts = try? c.decode(Double.self, forKey: .expiresAt) {
            expiresAt = Date(timeIntervalSince1970: ts)
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }
        user = try c.decode(InspectFlowUser.self, forKey: .user)
    }
}

public enum InspectFlowError: LocalizedError {
    case http(status: Int, body: String)
    case decoding(Error)
    case notAuthenticated
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .http(let s, let b): return "HTTP \(s): \(b)"
        case .decoding(let e): return "Decoding error: \(e)"
        case .notAuthenticated: return "Not authenticated"
        case .invalidResponse: return "Invalid response"
        }
    }
}
