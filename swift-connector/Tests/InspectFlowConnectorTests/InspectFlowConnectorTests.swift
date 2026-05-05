import XCTest
@testable import InspectFlowConnector

final class InspectFlowConnectorTests: XCTestCase {
    func testConfigBuildsURLs() {
        let cfg = InspectFlowConfig(
            url: URL(string: "https://aqtcgybbqdyjasgnuwlh.supabase.co")!,
            anonKey: "anon"
        )
        XCTAssertEqual(cfg.restURL.absoluteString, "https://aqtcgybbqdyjasgnuwlh.supabase.co/rest/v1")
        XCTAssertEqual(cfg.authURL.absoluteString, "https://aqtcgybbqdyjasgnuwlh.supabase.co/auth/v1")
        XCTAssertTrue(cfg.realtimeURL.absoluteString.hasPrefix("wss://"))
    }
}
