import Foundation

final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}

    func fetchMyProfile(userId: UUID) async throws -> UserProfile {
        // Placeholder HTTP request contract; wire to Supabase REST or Swift SDK.
        return UserProfile(id: userId, fullName: "Inspector", email: "inspector@example.com")
    }
}
