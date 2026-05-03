import Foundation

@MainActor
final class AppState: ObservableObject {
    enum AuthState {
        case loading
        case signedOut
        case signedIn(UserProfile)
    }

    @Published var authState: AuthState = .loading

    func bootstrap() async {
        do {
            if let session = try KeychainStore.shared.readSession() {
                let profile = try await SupabaseService.shared.fetchMyProfile(userId: session.userID)
                authState = .signedIn(profile)
            } else {
                authState = .signedOut
            }
        } catch {
            authState = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await SupabaseService.shared.signIn(email: email, password: password)
        try KeychainStore.shared.save(session: session)
        let profile = try await SupabaseService.shared.fetchMyProfile(userId: session.userID)
        authState = .signedIn(profile)
    }

    func signOut() {
        KeychainStore.shared.clearSession()
        authState = .signedOut
    }
}
