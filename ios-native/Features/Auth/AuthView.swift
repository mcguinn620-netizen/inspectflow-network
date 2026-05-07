import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if viewModel.mode == .signUp {
                        TextField("Full name", text: $viewModel.fullName)
                            .textContentType(.name)
                    }
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
                } header: {
                    Text(AINBrand.displayName)
                } footer: {
                    Text(AINBrand.tagline).font(.caption)
                }

                if let err = viewModel.errorMessage {
                    Section { Text(err).foregroundColor(AINBrand.fail).font(.footnote) }
                }

                Section {
                    Button {
                        Task { await viewModel.submit(appState: appState) }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isBusy { ProgressView() }
                            Text(viewModel.mode == .signIn ? "Sign In" : "Create Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!viewModel.canSubmit)

                    Button(viewModel.mode == .signIn ? "Need an account? Sign Up" : "Have an account? Sign In") {
                        viewModel.toggleMode()
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle(viewModel.mode == .signIn ? "Sign In" : "Sign Up")
        }
    }
}
