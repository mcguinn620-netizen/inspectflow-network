import Foundation
import InspectFlowConnector

/// Single shared `InspectFlowClient` for the app. Configured at first access.
enum SupabaseClientProvider {
    static let shared: InspectFlowClient = {
        let config = InspectFlowConfig(
            url: SupabaseConfig.baseURL,
            anonKey: SupabaseConfig.anonKey,
            keychainService: "com.autoinspectornetwork.ios",
            keychainAccount: "session"
        )
        return InspectFlowClient(config: config)
    }()
}
