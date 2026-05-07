import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                ProgressView("Loading")
            case .signedOut:
                AuthView(viewModel: AuthViewModel())
            case .signedIn:
                MainTabView()
            }
        }
    }
}
