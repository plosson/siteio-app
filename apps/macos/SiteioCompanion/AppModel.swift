import Foundation
import Observation

/// The app's state: which server's admin page the window shows, remembered between launches.
@MainActor @Observable final class AppModel {
    private static let serverKey = "serverURL"

    /// The admin page shown, or nil for the connect screen.
    private(set) var adminURL: URL?
    /// A new value reloads the admin page.
    private(set) var reloadToken = UUID()

    private let defaults: UserDefaults
    private let allowLocalHTTP: Bool

    init(defaults: UserDefaults = .standard, allowLocalHTTP: Bool) {
        self.defaults = defaults
        self.allowLocalHTTP = allowLocalHTTP
        // A remembered address is checked again: a value from an older build or another tool may not be one.
        adminURL = defaults.string(forKey: Self.serverKey).flatMap { ServerAddress.adminURL(from: $0, allowLocalHTTP: allowLocalHTTP) }
    }

    /// Show the server named by `input`; false when it is not a server address.
    func connect(to input: String) -> Bool {
        guard let url = ServerAddress.adminURL(from: input, allowLocalHTTP: allowLocalHTTP) else { return false }
        defaults.set(url.absoluteString, forKey: Self.serverKey)
        adminURL = url
        return true
    }

    /// Back to the connect screen; the next server replaces the remembered one.
    func switchServer() {
        defaults.removeObject(forKey: Self.serverKey)
        adminURL = nil
    }

    func reload() { reloadToken = UUID() }

    /// The window's title: the server's host, for the Window menu and Mission Control.
    var windowTitle: String { adminURL?.host.map { "SiteIO — \($0)" } ?? "SiteIO" }
}
