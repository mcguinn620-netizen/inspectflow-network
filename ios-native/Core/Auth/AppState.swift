import Foundation

@MainActor
final class AppState: ObservableObject {
    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn(UserProfile)
    }

    @Published var authState: AuthState = .loading
    @Published var activeOrganizationID: UUID?
    @Published var effectiveRole: String = "inspector"

    func bootstrap() async {
        let service = SupabaseService.shared
        guard let userID = service.currentUserID else {
            authState = .signedOut
            return
        }
        do {
            let profile = try await service.fetchMyProfile(userId: userID)
            if let membership = try? await service.fetchDefaultOrganization(userId: userID) {
                activeOrganizationID = membership.organizationID
                effectiveRole = membership.role
            }
            authState = .signedIn(profile)
        } catch {
            // Token might be stale; treat as signed out.
            try? await service.signOut()
            authState = .signedOut
        }
    }

    func didSignIn() async { await bootstrap() }

    func signOut() async {
        try? await SupabaseService.shared.signOut()
        activeOrganizationID = nil
        effectiveRole = "inspector"
        authState = .signedOut
    }
}
