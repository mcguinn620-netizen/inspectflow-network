import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""

    func signIn() async {}
}

struct AuthView: View {
    @StateObject var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $viewModel.email)
                SecureField("Password", text: $viewModel.password)
                Button("Sign In") { Task { await viewModel.signIn() } }
            }
            .navigationTitle("Sign In")
        }
    }
}
