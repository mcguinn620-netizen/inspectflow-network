import XCTest
@testable import InspectFlowConnector

final class InspectFlowConnectorTests: XCTestCase {
    func testConfigBuildsRestURL() {
        let cfg = InspectFlowConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "key")
        XCTAssertEqual(cfg.restURL.absoluteString, "https://example.supabase.co/rest/v1")
    }
}
