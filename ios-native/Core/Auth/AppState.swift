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
}
