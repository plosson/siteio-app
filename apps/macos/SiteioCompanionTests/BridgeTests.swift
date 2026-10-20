import XCTest
@testable import siteio_Companion

final class BridgeTests: XCTestCase {
    private let admin = Origin(url: URL(string: "https://api.example.com/ui")!)

    func testTheOneCallThePageMakes() {
        XCTAssertEqual(BridgeCall(message: ["method": "dragWindow", "args": [Any]()]), .dragWindow)
    }

    func testMalformedMessagesAreDropped() {
        let bodies: [Any] = [
            "dragWindow",
            ["method": "dragWindow"],
            ["args": [Any]()],
            ["method": "dragWindow", "args": ["now"]],
            ["method": "dragWindow", "args": "[]"],
            ["method": "dragWindow", "args": [Any](), "extra": 1],
            ["method": "DragWindow", "args": [Any]()],
            ["method": "openTerminal", "args": [Any]()],
            ["method": "addProfile", "args": ["gmail"]],
            ["method": 1, "args": [Any]()],
            NSNull(),
        ]
        for body in bodies {
            XCTAssertNil(BridgeCall(message: body), "\(body)")
        }
    }

    func testOnlyTheMainFrameOfTheServersOwnOriginMayCall() {
        let body: [String: Any] = ["method": "dragWindow", "args": [Any]()]
        XCTAssertEqual(BridgeHandler.accept(body: body, isMainFrame: true,
                                            from: Origin(scheme: "https", host: "API.example.com", port: 0), allowed: admin), .dragWindow)
        XCTAssertEqual(BridgeHandler.accept(body: body, isMainFrame: true,
                                            from: Origin(scheme: "https", host: "api.example.com", port: 443), allowed: admin), .dragWindow)

        // A frame inside the admin, a site of the same server, another port, plain http, a look-alike host.
        XCTAssertNil(BridgeHandler.accept(body: body, isMainFrame: false,
                                          from: Origin(scheme: "https", host: "api.example.com", port: 443), allowed: admin))
        for origin in [Origin(scheme: "https", host: "blog.example.com", port: 443),
                       Origin(scheme: "https", host: "api.example.com", port: 8443),
                       Origin(scheme: "http", host: "api.example.com", port: 80),
                       Origin(scheme: "https", host: "api.example.com.evil.com", port: 443),
                       Origin(scheme: "https", host: "", port: 0)] {
            XCTAssertNil(BridgeHandler.accept(body: body, isMainFrame: true, from: origin, allowed: admin), "\(origin)")
        }
        // No admin origin at all: nothing is accepted.
        XCTAssertNil(BridgeHandler.accept(body: body, isMainFrame: true,
                                          from: Origin(scheme: "https", host: "api.example.com", port: 443), allowed: nil))
    }

    func testTheBridgeScriptExposesOnlyPresentAndDragWindow() {
        XCTAssertTrue(bridgeScript.contains("present: true"))
        XCTAssertTrue(bridgeScript.contains("dragWindow:"))
        XCTAssertTrue(bridgeScript.contains("Object.freeze"))
        XCTAssertFalse(bridgeScript.contains("eval"))
    }
}
