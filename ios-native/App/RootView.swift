import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                ProgressView("Loading")
            case .signedOut:
                if AuthBypass.isEnabled {
                    DebugUserPickerView()
                } else {
                    #if DEBUG
                    DebugUserPickerView()
                    #else
                    AuthView(viewModel: AuthViewModel())
                    #endif
                }
            case .signedIn:
                MainTabView()
            }
        }
    }
}
