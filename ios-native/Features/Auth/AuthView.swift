import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        // TODO: Replace placeholder with Supabase auth sign in using Supabase Swift SDK.
        // TODO: Persist auth session securely in KeychainStore after a successful sign-in.
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            errorMessage = "Placeholder sign-in only. Wire Supabase auth next."
        } catch {
            errorMessage = "Sign-in cancelled."
        }
    }
}

struct AuthView: View {
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
                    Task { await viewModel.signIn() }
                }
                .disabled(viewModel.isLoading)
            }
            .navigationTitle("Sign In")
        }
    }
}
