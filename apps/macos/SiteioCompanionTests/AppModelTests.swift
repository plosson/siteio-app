import XCTest
@testable import SiteIO

@MainActor final class AppModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "siteio-companion-tests"
    private var dir: URL!
    private var cliFile: URL { dir.appending(path: "config.json") }

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        dir = FileManager.default.temporaryDirectory.appending(path: "AppModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: dir)
    }

    private func model(local: Bool = false) -> AppModel {
        AppModel(defaults: defaults, allowLocalHTTP: local, cliFile: cliFile)
    }

    private func writeCLI(current: String?, _ servers: [String: [String: Any]]) throws {
        var json: [String: Any] = ["servers": servers]
        if let current { json["current"] = current }
        try JSONSerialization.data(withJSONObject: json).write(to: cliFile)
    }

    private func url(_ s: String) -> URL { URL(string: s)! }

    func testNoServersAndNoCLIShowsTheConnectScreen() {
        let m = model()
        XCTAssertTrue(m.servers.isEmpty)
        XCTAssertTrue(m.showsConnect)
        XCTAssertEqual(m.windowTitle, "SiteIO")
    }

    func testTheCLIsServersAreThereSignedInAndItsCurrentOneIsShownFirst() throws {
        try writeCLI(current: "b.example.com", [
            "a.example.com": ["apiUrl": "https://api.a.example.com", "apiKey": "key-a"],
            "b.example.com": ["apiUrl": "https://api.b.example.com", "apiKey": "key-b"],
        ])
        let m = model()
        XCTAssertEqual(m.servers.map(\.name), ["a.example.com", "b.example.com"])
        XCTAssertEqual(m.selected?.name, "b.example.com")
        XCTAssertEqual(m.selected?.launchURL.absoluteString, "https://api.b.example.com/ui?key=key-b")
        XCTAssertFalse(m.showsConnect)
        XCTAssertEqual(m.windowTitle, "SiteIO — b.example.com")
    }

    func testTheCLIsKeysAreNeverWrittenToThePreferences() throws {
        try writeCLI(current: "a.example.com", ["a.example.com": ["apiUrl": "https://api.a.example.com", "apiKey": "secret-key-123"]])
        let m = model()
        XCTAssertTrue(m.connect(to: "other.example.com"))
        m.select(url("https://api.a.example.com/ui"))
        let stored = defaults.dictionaryRepresentation().description
        XCTAssertFalse(stored.contains("secret-key-123"))
    }

    func testAServerAddedInTheAppIsRememberedAndShown() {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        XCTAssertEqual(m.selected?.launchURL.absoluteString, "https://api.example.com/ui")
        let again = model()
        XCTAssertEqual(again.servers.map(\.name), ["example.com"])
        XCTAssertEqual(again.selected?.name, "example.com")
    }

    func testARefusedAddressChangesNothing() {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        XCTAssertFalse(m.connect(to: "javascript:alert(1)"))
        XCTAssertEqual(m.servers.count, 1)
        XCTAssertEqual(m.selected?.name, "example.com")
    }

    func testAddingAServerTwiceKeepsOneEntry() {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        XCTAssertTrue(m.connect(to: "https://api.example.com/ui#/services"))
        XCTAssertEqual(m.servers.count, 1)
    }

    func testAServerInBothPlacesIsOneEntryThatSignsInWithTheCLIKey() throws {
        try writeCLI(current: nil, ["example.com": ["apiUrl": "https://api.example.com", "apiKey": "k"]])
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        XCTAssertEqual(m.servers.count, 1)
        XCTAssertEqual(m.servers.first?.addedInApp, true)
        XCTAssertEqual(m.servers.first?.cliKey, "k")
    }

    func testRemovingKeepsTheCLIsServersAndMovesToAnother() throws {
        try writeCLI(current: nil, ["cli.example.com": ["apiUrl": "https://api.cli.example.com", "apiKey": "k"]])
        let m = model()
        XCTAssertTrue(m.connect(to: "mine.example.com"))
        m.remove(url("https://api.mine.example.com/ui"))
        XCTAssertEqual(m.servers.map(\.name), ["cli.example.com"])
        XCTAssertEqual(m.selected?.name, "cli.example.com")
        // A CLI server cannot be removed here: `siteio logout` does it.
        m.remove(url("https://api.cli.example.com/ui"))
        XCTAssertEqual(m.servers.map(\.name), ["cli.example.com"])
    }

    func testSelectingAnUnknownServerChangesNothing() {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        m.select(url("https://api.evil.com/ui"))
        XCTAssertEqual(m.selected?.name, "example.com")
    }

    func testALogoutInTheCLIDropsItsServerOnRefresh() throws {
        try writeCLI(current: "a.example.com", ["a.example.com": ["apiUrl": "https://api.a.example.com", "apiKey": "k"]])
        let m = model()
        XCTAssertEqual(m.selected?.name, "a.example.com")
        try writeCLI(current: nil, [:])
        m.refreshServers()
        XCTAssertNil(m.selected)
        XCTAssertTrue(m.showsConnect)
    }

    func testAddingThenCancellingGoesBackToTheServer() {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        m.startAdding()
        XCTAssertTrue(m.showsConnect)
        m.cancelAdding()
        XCTAssertFalse(m.showsConnect)
    }

    func testTheOneServerOfOlderVersionsIsCarriedOver() {
        defaults.set("https://api.example.com/ui", forKey: "serverURL")
        let m = model()
        XCTAssertEqual(m.selected?.name, "example.com")
        XCTAssertNil(defaults.string(forKey: "serverURL"))
    }

    func testARememberedValueIsCheckedAgainAtLaunch() {
        // A Release build must not open a plain-http page a Debug build remembered.
        defaults.set(["http://localhost:3000/ui", "file:///etc/passwd"], forKey: "servers")
        defaults.set("http://localhost:3000/ui", forKey: "selectedServer")
        XCTAssertTrue(model(local: false).servers.isEmpty)
        XCTAssertEqual(model(local: true).servers.map(\.name), ["localhost:3000"])
    }

    func testReloadChangesTheTokenEveryTime() {
        let m = model()
        let first = m.reloadToken
        m.reload()
        let second = m.reloadToken
        m.reload()
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(second, m.reloadToken)
    }

    func testTheFooterVersionComesFromTheShownServersHealthAndTheLatestRelease() async {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        await m.loadVersions { url in
            switch url.absoluteString {
            case "https://api.example.com/health": Data(#"{"success":true,"data":{"status":"ok","version":"1.49.0"}}"#.utf8)
            case SiteioVersion.latestReleaseURL.absoluteString: Data(#"{"tag_name":"v1.50.1"}"#.utf8)
            default: nil
            }
        }
        XCTAssertEqual(m.footerVersion, .updateAvailable(current: "1.49.0", latest: "1.50.1"))
    }

    func testAnUnreachableServerLeavesTheFooterWithoutAVersion() async {
        let m = model()
        XCTAssertTrue(m.connect(to: "example.com"))
        await m.loadVersions { _ in nil }
        XCTAssertEqual(m.footerVersion, .unknown)
    }
}
