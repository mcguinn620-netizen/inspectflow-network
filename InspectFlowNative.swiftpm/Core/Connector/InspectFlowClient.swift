import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
        self.auth = AuthClient(config: config, session: store)
        self.db = RestClient(config: config, session: store)
        self.realtime = RealtimeClient(config: config, session: store)
        self.storage = StorageClient(config: config, session: store)
        self.functions = FunctionsClient(config: config, session: store)
    }
}
