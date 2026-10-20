import XCTest
@testable import SiteIO

final class CLIServersTests: XCTestCase {
    private var dir: URL!
    private var file: URL { dir.appending(path: "config.json") }

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "CLIServersTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws { try? FileManager.default.removeItem(at: dir) }

    private func read(_ text: String, local: Bool = false) throws -> (servers: [CLIServers.Entry], current: URL?) {
        try Data(text.utf8).write(to: file)
        return CLIServers.read(file, allowLocalHTTP: local)
    }

    func testTheCLIsConfigAsSiteioLoginWritesIt() throws {
        let r = try read(#"{"current":"example.com","servers":{"example.com":{"apiUrl":"https://api.example.com","apiKey":"abc"},"other.com":{"apiUrl":"https://api.other.com","apiKey":"def","username":"alex"}}}"#)
        XCTAssertEqual(r.servers.map(\.adminURL.absoluteString), ["https://api.example.com/ui", "https://api.other.com/ui"])
        XCTAssertEqual(r.servers.map(\.apiKey), ["abc", "def"])
        XCTAssertEqual(r.current?.absoluteString, "https://api.example.com/ui")
    }

    func testAMissingUnreadableOrMalformedFileGivesNoServers() throws {
        XCTAssertTrue(CLIServers.read(dir.appending(path: "nope.json"), allowLocalHTTP: true).servers.isEmpty)
        XCTAssertTrue(CLIServers.read(dir, allowLocalHTTP: true).servers.isEmpty) // a folder
        for text in ["", "{", "[]", "null", #"{"servers":[]}"#, #"{"servers":"x"}"#, #"{"apiUrl":"https://api.legacy.com","apiKey":"k"}"#] {
            XCTAssertTrue(try read(text).servers.isEmpty, text)
        }
    }

    func testAHugeFileIsNotRead() throws {
        let big = #"{"servers":{"example.com":{"apiUrl":"https://api.example.com","apiKey":"k"}},"pad":""# + String(repeating: "x", count: 1_100_000) + #""}"#
        XCTAssertTrue(try read(big).servers.isEmpty)
    }

    func testBadEntriesAreSkippedAndTheRestKept() throws {
        let r = try read(#"""
        {"current":"bad1","servers":{
          "good.com":{"apiUrl":"https://api.good.com","apiKey":"k"},
          "bad1":{"apiUrl":"javascript:alert(1)","apiKey":"k"},
          "bad2":{"apiUrl":"http://api.plain.com","apiKey":"k"},
          "bad3":{"apiUrl":"https://api.nokey.com"},
          "bad4":{"apiUrl":"https://api.emptykey.com","apiKey":""},
          "bad5":{"apiUrl":"https://api.spacekey.com","apiKey":"a b"},
          "bad6":{"apiUrl":"https://api.newline.com","apiKey":"a\nb"},
          "bad7":{"apiUrl":"https://api.unicode.com","apiKey":"clé"},
          "bad8":{"apiUrl":"api.noscheme.com","apiKey":"k"},
          "bad9":{"apiUrl":"https://user:pw@api.creds.com","apiKey":"k"},
          "bad10":{"apiUrl":42,"apiKey":"k"},
          "bad11":"https://api.string.com"
        }}
        """#)
        XCTAssertEqual(r.servers.map(\.adminURL.host), ["api.good.com"])
        XCTAssertNil(r.current, "the current server is one of the skipped ones")
    }

    func testLocalServersOnlyWhenPlainHttpIsAllowed() throws {
        let text = #"{"servers":{"localhost":{"apiUrl":"http://localhost:3000","apiKey":"k"}}}"#
        XCTAssertTrue(try read(text, local: false).servers.isEmpty)
        XCTAssertEqual(try read(text, local: true).servers.map(\.adminURL.absoluteString), ["http://localhost:3000/ui"])
    }

    func testTwoNamesForOneServerGiveOneEntry() throws {
        let r = try read(#"{"servers":{"a":{"apiUrl":"https://api.example.com","apiKey":"k1"},"b":{"apiUrl":"https://API.example.com/","apiKey":"k2"}}}"#)
        XCTAssertEqual(r.servers.count, 1)
    }

    func testTheKeyReachesThePageAsWritten() {
        let admin = URL(string: "https://api.example.com/ui")!
        for key in ["abc", "a+b", "a&b=c", "a#b", "a/b?c", "%41", "a;b"] {
            let launch = CLIServers.signedInURL(admin, key: key)
            XCTAssertEqual(launch.host, "api.example.com", key)
            XCTAssertEqual(launch.path, "/ui", key)
            XCTAssertNil(launch.fragment, key)
            // What the page's URLSearchParams reads: form-decoding, so a raw "+" would turn into a space.
            let query = launch.query(percentEncoded: true) ?? ""
            XCTAssertFalse(query.contains("+") || query.contains("&") || query.contains("#"), key)
            XCTAssertEqual(URLComponents(url: launch, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "key" }?.value, key)
        }
    }
}
