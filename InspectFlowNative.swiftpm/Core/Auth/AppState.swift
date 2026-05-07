import Foundation

@MainActor
final class AppState: ObservableObject {
    enum AuthState {
        case loading
        case signedOut
        case signedIn(UserProfile)
    }

    @Published var authState: AuthState = .loading

    private let repository = AppRepository.shared

    func bootstrap() async {
        guard let session = repository.currentSession() else {
            authState = .signedOut
            return
        }

        do {
            let profile = try await repository.profile(userId: session.user.id)
            authState = .signedIn(profile)
        } catch {
            authState = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await repository.signIn(email: email, password: password)
        let profile = try await repository.profile(userId: session.user.id)
        authState = .signedIn(profile)
    }

    func signOut() {
        Task { await repository.signOut() }
        authState = .signedOut
    }
}
