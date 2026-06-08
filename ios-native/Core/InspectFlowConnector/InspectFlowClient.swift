import Foundation

public final class InspectFlowClient {
    public let config: InspectFlowConfig
    public let auth: AuthClient
    public let db: RestClient
    public let realtime: RealtimeClient
    public let storage: StorageClient
    public let functions: FunctionsClient

    private let session: SessionStore

    public convenience init(url: URL, anonKey: String) {
        self.init(config: InspectFlowConfig(url: url, anonKey: anonKey))
    }

    public init(config: InspectFlowConfig) {
        self.config = config
        
        // 1. Initialize the session store
        let store = SessionStore(config: config)
        self.session = store
        
        // 2. Initialize the auth client
        let auth = AuthClient(config: config, session: store)
        self.auth = auth
        
        // 3. Initialize services using the necessary dependencies
        self.db = RestClient(config: config, auth: auth)
        self.realtime = RealtimeClient(config: config, session: store)
        self.storage = StorageClient(config: config, auth: auth)
        
        // 4. Corrected initialization for FunctionsClient
        // It requires (config: InspectFlowConfig, auth: AuthClient)
        self.functions = FunctionsClient(config: config, auth: auth)
    }
}

