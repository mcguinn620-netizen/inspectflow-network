import Foundation

public final class RestClient {
    private let config: InspectFlowConfig
    private let session: SessionStore
    private let urlSession: URLSession

    init(config: InspectFlowConfig, session: SessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.session = session
        self.urlSession = urlSession
    }

    public func from(_ table: String) -> QueryBuilder {
        QueryBuilder(table: table, config: config, session: session, urlSession: urlSession)
    }
}
