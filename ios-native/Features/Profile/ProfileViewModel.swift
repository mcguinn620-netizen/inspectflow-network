import Foundation
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var phone: String = ""
    @Published var email: String = ""
    @Published var avatarPath: String?
    @Published var avatarURL: URL?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let profile = try await SupabaseService.shared.fetchMyProfile(userId: userId)
            fullName = profile.fullName ?? ""
            phone = profile.phone ?? ""
            email = profile.email ?? ""
            avatarPath = profile.avatarUrl
            if let path = profile.avatarUrl, !path.isEmpty {
                avatarURL = try? await SupabaseService.shared.avatarSignedURL(path: path)
            }
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    func save(userId: UUID) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseService.shared.updateProfile(
                userId: userId,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarUrl: nil
            )
            statusMessage = "Profile updated."
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }

    func uploadAvatar(userId: UUID, data: Data) async {
        do {
            let path = try await SupabaseService.shared.uploadAvatar(userId: userId, data: data)
            try await SupabaseService.shared.updateProfile(userId: userId, fullName: nil, phone: nil, avatarUrl: path)
            avatarPath = path
            avatarURL = try? await SupabaseService.shared.avatarSignedURL(path: path)
            statusMessage = "Avatar updated."
        } catch {
            errorMessage = AINFriendlyError.message(for: error)
        }
    }
}
