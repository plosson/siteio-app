import XCTest
@testable import SiteIO

@MainActor final class AppModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "siteio-companion-tests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func testARefusedAddressChangesNothing() {
        let model = AppModel(defaults: defaults, allowLocalHTTP: false)
        XCTAssertTrue(model.connect(to: "example.com"))
        XCTAssertFalse(model.connect(to: "javascript:alert(1)"))
        XCTAssertEqual(model.adminURL?.absoluteString, "https://api.example.com/ui")
        XCTAssertEqual(AppModel(defaults: defaults, allowLocalHTTP: false).adminURL?.absoluteString, "https://api.example.com/ui")
    }

    func testARememberedValueIsCheckedAgainAtLaunch() {
        defaults.set("http://localhost:3000/ui", forKey: "serverURL")
        // A Release build must not open a plain-http page a Debug build remembered.
        XCTAssertNil(AppModel(defaults: defaults, allowLocalHTTP: false).adminURL)
        defaults.set("file:///etc/passwd", forKey: "serverURL")
        XCTAssertNil(AppModel(defaults: defaults, allowLocalHTTP: true).adminURL)
    }

    func testSwitchingServerForgetsTheOldOne() {
        let model = AppModel(defaults: defaults, allowLocalHTTP: false)
        XCTAssertTrue(model.connect(to: "example.com"))
        model.switchServer()
        XCTAssertNil(model.adminURL)
        XCTAssertNil(AppModel(defaults: defaults, allowLocalHTTP: false).adminURL)
        XCTAssertEqual(model.windowTitle, "SiteIO")
    }

    func testReloadChangesTheTokenEveryTime() {
        let model = AppModel(defaults: defaults, allowLocalHTTP: false)
        let first = model.reloadToken
        model.reload()
        let second = model.reloadToken
        model.reload()
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(second, model.reloadToken)
    }
}
