import Foundation

final class AppRepository {
    static let shared = AppRepository()

    let client: InspectFlowClient

    private init() {
        let config = InspectFlowConfig(url: LocalSupabaseConfig.url, anonKey: LocalSupabaseConfig.anonKey)
        self.client = InspectFlowClient(config: config)
    }

    func signIn(email: String, password: String) async throws -> InspectFlowSession {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func currentSession() -> InspectFlowSession? {
        client.auth.currentSession
    }

    func profile(userId: UUID) async throws -> UserProfile {
        let rows: [UserProfile] = try await client.db.from("profiles")
            .select("id,full_name,email,role")
            .eq("id", userId.uuidString)
            .limit(1)
            .execute()
        return rows.first ?? UserProfile(id: userId, fullName: "Inspector", email: nil, role: "inspector")
    }
}
