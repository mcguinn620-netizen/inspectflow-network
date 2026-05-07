import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode { case signIn, signUp }

    @Published var mode: Mode = .signIn
    @Published var email = ""
    @Published var password = ""
    @Published var fullName = ""
    @Published var isBusy = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        guard !isBusy, email.contains("@"), password.count >= 6 else { return false }
        if mode == .signUp { return !fullName.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    func toggleMode() {
        mode = (mode == .signIn) ? .signUp : .signIn
        errorMessage = nil
    }

    func submit(appState: AppState) async {
        guard canSubmit else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            switch mode {
            case .signIn:
                _ = try await SupabaseService.shared.signIn(email: email, password: password)
            case .signUp:
                _ = try await SupabaseService.shared.signUp(email: email, password: password, fullName: fullName)
            }
            await appState.didSignIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
