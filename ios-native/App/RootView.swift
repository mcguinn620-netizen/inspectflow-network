import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        #if DEBUG
        Group {
            switch appState.authState {
            case .loading:
                ProgressView("Loading")
            case .signedOut:
                // No debug user picked yet → show DEBUG picker instead of Supabase auth.
                // Real Supabase auth still works via the "Use real auth" link.
                DebugUserPickerView()
            case .signedIn:
                MainTabView()
            }
        }
        #else
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
        #endif
    }
}
