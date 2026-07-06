import Foundation
import SwiftUI

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

    @Published var selectedDebugUser: DebugUser?
    private let debugUserIDKey = "debugUserID"
    private let debugUserPayloadKey = "debugUserPayload"

    func bootstrap() async {
        if AuthBypass.isEnabled {
            if let user = loadStoredDebugUser() {
                applyDebugUser(user)
            } else {
                authState = .signedOut
            }
            return
        }

        #if DEBUG
        if let user = loadStoredDebugUser() {
            applyDebugUser(user)
            return
        }
        if let idString = UserDefaults.standard.string(forKey: debugUserIDKey),
           let id = UUID(uuidString: idString) {
            if let user = try? await DebugUserService.fetchOne(id: id) {
                applyDebugUser(user)
                return
            }
        }
        #endif

        let service = SupabaseService.shared
        do {
            let session = try await service.restoreAndValidateSession()
            let userID = session.user.id
            let profile = try await service.fetchMyProfile(userId: userID)
            if let membership = try? await service.fetchDefaultOrganization(userId: userID) {
                activeOrganizationID = membership.organizationID
                effectiveRole = membership.role
            }
            authState = .signedIn(profile)
        } catch {
            try? await service.signOut()
            authState = .signedOut
        }
    }

    func didSignIn() async { await bootstrap() }

    func signOut() async {
        if AuthBypass.isEnabled {
            clearDebugUser()
            return
        }
        try? await SupabaseService.shared.signOut()
        activeOrganizationID = nil
        effectiveRole = "inspector"
        authState = .signedOut
        #if DEBUG
        clearDebugUser()
        #endif
    }

    func debugSignIn(as user: DebugUser) {
        UserDefaults.standard.set(user.id.uuidString, forKey: debugUserIDKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: debugUserPayloadKey)
        }
        applyDebugUser(user)
    }

    func clearDebugUser() {
        UserDefaults.standard.removeObject(forKey: debugUserIDKey)
        UserDefaults.standard.removeObject(forKey: debugUserPayloadKey)
        selectedDebugUser = nil
        activeOrganizationID = nil
        effectiveRole = "inspector"
        authState = .signedOut
    }

    private func applyDebugUser(_ user: DebugUser) {
        selectedDebugUser = user
        activeOrganizationID = user.organizationID
        effectiveRole = user.role
        let profile = UserProfile(
            id: user.id,
            fullName: user.fullName,
            email: user.email
        )
        authState = .signedIn(profile)
    }

    private func loadStoredDebugUser() -> DebugUser? {
        guard let data = UserDefaults.standard.data(forKey: debugUserPayloadKey) else { return nil }
        return try? JSONDecoder().decode(DebugUser.self, from: data)
    }
}
