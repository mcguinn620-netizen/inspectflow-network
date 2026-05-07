import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    func signIn(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.signIn(email: email, password: password)
        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $viewModel.password)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                Button(viewModel.isLoading ? "Signing In..." : "Sign In") {
                    Task { await viewModel.signIn(appState: appState) }
                }
                .disabled(viewModel.isLoading)
            }
            .navigationTitle("Sign In")
        }
    }
}
