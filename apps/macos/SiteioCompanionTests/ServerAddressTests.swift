import XCTest
@testable import SiteIO

final class ServerAddressTests: XCTestCase {
    private func url(_ input: String, local: Bool = false) -> String? {
        ServerAddress.adminURL(from: input, allowLocalHTTP: local)?.absoluteString
    }

    func testBareDomainGoesToItsApiHost() {
        XCTAssertEqual(url("sitedebile.fr"), "https://api.sitedebile.fr/ui")
        XCTAssertEqual(url("  SiteDebile.FR \n"), "https://api.sitedebile.fr/ui")
        XCTAssertEqual(url("api.houlahop.com"), "https://api.houlahop.com/ui")
    }

    func testAnAddressWithASchemeKeepsItsHostButNotItsPathQueryOrFragment() {
        XCTAssertEqual(url("https://admin.example.com"), "https://admin.example.com/ui")
        XCTAssertEqual(url("https://api.example.com/ui#/services?key=secret"), "https://api.example.com/ui")
        XCTAssertEqual(url("https://api.example.com/../../etc/passwd?x=1"), "https://api.example.com/ui")
        XCTAssertEqual(url("https://api.example.com:8443/whatever"), "https://api.example.com:8443/ui")
    }

    func testPlainHttpIsRefusedForRemoteHostsEvenWhenLocalHttpIsAllowed() {
        XCTAssertNil(url("http://api.example.com"))
        XCTAssertNil(url("http://api.example.com", local: true))
        XCTAssertNil(url("http://localhost:3000"))
        XCTAssertEqual(url("http://localhost:3000", local: true), "http://localhost:3000/ui")
        XCTAssertEqual(url("http://127.0.0.1:4600/ui", local: true), "http://127.0.0.1:4600/ui")
    }

    func testOtherSchemesAreRefused() {
        for input in ["javascript:alert(1)", "file:///etc/passwd", "ftp://api.example.com", "data:text/html,hi",
                      "siteio://api.example.com", "wss://api.example.com"] {
            XCTAssertNil(url(input, local: true), input)
        }
    }

    func testCredentialsInTheAddressAreRefused() {
        XCTAssertNil(url("https://user:pass@api.example.com"))
        XCTAssertNil(url("https://user@api.example.com"))
        // A bare "trusted.com@evil.com" would otherwise open evil.com.
        XCTAssertNil(url("trusted.com@evil.com"))
    }

    func testNotADomainIsRefused() {
        for input in ["", "   ", "localhost", "example", "exa mple.com", "example..com", ".example.com", "example.com.",
                      "-bad.example.com", "bad-.example.com", "ex_ample.com", "exämple.com", "192.168.1.10",
                      "https://", "https:///ui", "\u{0}example.com", "example.com\u{7}", "a.123",
                      String(repeating: "a", count: 64) + ".com", String(repeating: "a.", count: 1200) + "com"] {
            XCTAssertNil(url(input, local: true), input.debugDescription)
        }
    }

    func testANewlineInsideTheAddressIsRefusedNotTrimmed() {
        XCTAssertNil(url("example.com\nevil.com"))
        XCTAssertNil(url("https://api.example.com\r\n/ui"))
    }
}
