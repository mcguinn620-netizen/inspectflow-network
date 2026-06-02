import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    #if DEBUG
    @AppStorage("debugLoginBypass")
    private var debugLoginBypass = true
    #endif

    var body: some View {

        #if DEBUG

        if debugLoginBypass {

            MainTabView()

        } else {

            Group {
                switch appState.authState {

                case .loading:
                    ProgressView("Loading")

                case .signedOut:
                    AuthView(
                        viewModel: AuthViewModel()
                    )

                case .signedIn:
                    MainTabView()
                }
            }
        }

        #else

        Group {
            switch appState.authState {

            case .loading:
                ProgressView("Loading")

            case .signedOut:
                AuthView(
                    viewModel: AuthViewModel()
                )

            case .signedIn:
                MainTabView()
            }
        }

        #endif
    }
}