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
        let store = SessionStore(config: config)
        self.session = store
        let auth = AuthClient(config: config, session: store)
        self.auth = auth
        self.db = RestClient(config: config, auth: auth)
        self.realtime = RealtimeClient(config: config, session: store)
        self.storage = StorageClient(config: config, auth: auth)
        self.functions = FunctionsClient(config: config, auth: auth)
    }
}
