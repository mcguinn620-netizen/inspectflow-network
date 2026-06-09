import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class RestClient {
    private let config: InspectFlowConfig
    private let auth: AuthClient
    private let urlSession: URLSession

    init(config: InspectFlowConfig, auth: AuthClient, urlSession: URLSession = .shared) {
        self.config = config
        self.auth = auth
        self.urlSession = urlSession
    }

    public func from(_ table: String) -> QueryBuilder {
        QueryBuilder(table: table, config: config, auth: auth, session: urlSession)
    }

    public func rpc(_ function: String, params: [String: Any] = [:]) -> QueryBuilder {
        QueryBuilder(table: "rpc/\(function)", config: config, auth: auth, session: urlSession)
            .rpc(params)
    }
}
