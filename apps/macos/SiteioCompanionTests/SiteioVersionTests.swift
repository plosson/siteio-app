import XCTest
@testable import SiteIO

final class SiteioVersionTests: XCTestCase {
    func testStatus() {
        XCTAssertEqual(SiteioVersion.status(server: nil, latest: "1.50.1"), .unknown)
        XCTAssertEqual(SiteioVersion.status(server: "1.50.1", latest: nil), .version("1.50.1"))
        XCTAssertEqual(SiteioVersion.status(server: "1.50.1", latest: "1.50.1"), .upToDate("1.50.1"))
        XCTAssertEqual(SiteioVersion.status(server: "1.51.0", latest: "1.50.1"), .upToDate("1.51.0"))
        XCTAssertEqual(SiteioVersion.status(server: "1.9.0", latest: "1.10.0"), .updateAvailable(current: "1.9.0", latest: "1.10.0"))
        XCTAssertEqual(SiteioVersion.status(server: "1.50.1", latest: "garbage"), .version("1.50.1"))
    }

    func testCompareIsNumericNotTextual() {
        XCTAssertEqual(SiteioVersion.compare("1.9.0", "1.10.0"), .orderedAscending)
        XCTAssertEqual(SiteioVersion.compare("v2.0.0", "1.99.99"), .orderedDescending)
        XCTAssertEqual(SiteioVersion.compare("1.50.1", "v1.50.1"), .orderedSame)
    }

    func testOnlyThreeNumbersAreVersions() {
        for bad in ["", "1", "1.2", "1.2.3.4", "1..3", "1.2.x", "-1.2.3", "1.2.3-beta", " 1.2.3", "１.２.３", "1.2.3\n", "1.2.9999999999"] {
            XCTAssertNil(SiteioVersion.compare(bad, "1.0.0"), bad.debugDescription)
        }
    }

    func testHealth() {
        XCTAssertEqual(SiteioVersion.parseHealth(Data(#"{"success":true,"data":{"status":"ok","version":"1.50.1"}}"#.utf8)), "1.50.1")
        for bad in [#"{"version":"1.50.1"}"#, #"{"data":{"version":1}}"#, #"{"data":{"version":"<script>"}}"#, "not json", ""] {
            XCTAssertNil(SiteioVersion.parseHealth(Data(bad.utf8)), bad)
        }
    }

    func testLatestRelease() {
        XCTAssertEqual(SiteioVersion.parseLatestRelease(Data(#"{"tag_name":"v1.50.1","name":"x"}"#.utf8)), "1.50.1")
        XCTAssertEqual(SiteioVersion.parseLatestRelease(Data(#"{"tag_name":"1.50.1"}"#.utf8)), "1.50.1")
        for bad in [#"{"message":"API rate limit exceeded"}"#, #"{"tag_name":"latest"}"#, #"{"tag_name":null}"#, "[]"] {
            XCTAssertNil(SiteioVersion.parseLatestRelease(Data(bad.utf8)), bad)
        }
    }
}
