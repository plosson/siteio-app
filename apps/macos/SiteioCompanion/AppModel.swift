import Foundation
import Observation

/// One siteio server the window can show.
struct Server: Identifiable, Equatable, Sendable {
    let adminURL: URL
    /// Logged in with the siteio CLI: its key opens the page signed in. Never stored by the app.
    var cliKey: String?
    /// Added in the app (remembered in its preferences); a server can be both.
    var addedInApp: Bool

    var id: URL { adminURL }
    /// The server's domain, as the CLI names it: the admin host without `api.`.
    var name: String {
        let host = adminURL.host ?? adminURL.absoluteString
        let shown = host.hasPrefix("api.") ? String(host.dropFirst(4)) : host
        return adminURL.port.map { "\(shown):\($0)" } ?? shown
    }
    /// The page to load: signed in with the CLI's key when there is one, as `siteio ui` does.
    var launchURL: URL { cliKey.map { CLIServers.signedInURL(adminURL, key: $0) } ?? adminURL }
}

/// The app's state: the servers, the one the window shows, remembered between launches.
@MainActor @Observable final class AppModel {
    private static let serversKey = "servers"
    private static let selectedKey = "selectedServer"
    /// One server only, before several: read once, then moved to `servers`.
    private static let legacyKey = "serverURL"

    /// Sorted by name, so ⌘1…⌘9 stay put.
    private(set) var servers: [Server] = []
    private(set) var selectedID: URL?
    /// The connect screen over the servers (Add Server…).
    private(set) var isAdding = false
    /// A new value reloads the admin page.
    private(set) var reloadToken = UUID()
    /// The siteio each server runs (its /health), and the latest release, for the footer.
    private(set) var serverVersions: [URL: String] = [:]
    private(set) var latestSiteio: String?

    private let defaults: UserDefaults
    private let allowLocalHTTP: Bool
    private let cliFile: URL

    init(defaults: UserDefaults = .standard, allowLocalHTTP: Bool, cliFile: URL = CLIServers.defaultFile) {
        self.defaults = defaults
        self.allowLocalHTTP = allowLocalHTTP
        self.cliFile = cliFile
        if let legacy = defaults.string(forKey: Self.legacyKey) {
            defaults.removeObject(forKey: Self.legacyKey)
            if defaults.stringArray(forKey: Self.serversKey) == nil {
                defaults.set([legacy], forKey: Self.serversKey)
                defaults.set(legacy, forKey: Self.selectedKey)
            }
        }
        let cliCurrent = refreshServers()
        // A remembered choice is checked again: a value from an older build or another tool may not be one.
        let remembered = defaults.string(forKey: Self.selectedKey).flatMap { ServerAddress.adminURL(from: $0, allowLocalHTTP: allowLocalHTTP) }
        selectedID = [remembered, cliCurrent, servers.first?.id].compactMap { $0 }.first { id in servers.contains { $0.id == id } }
    }

    var selected: Server? { servers.first { $0.id == selectedID } }

    /// The connect screen is shown: no server yet, or Add Server….
    var showsConnect: Bool { isAdding || selected == nil }

    /// Reads the app's own servers and the CLI's again; returns the CLI's current server.
    /// The window keeps its server while it is still known.
    @discardableResult func refreshServers() -> URL? {
        let added = (defaults.stringArray(forKey: Self.serversKey) ?? []).compactMap { ServerAddress.adminURL(from: $0, allowLocalHTTP: allowLocalHTTP) }
        let cli = CLIServers.read(cliFile, allowLocalHTTP: allowLocalHTTP)
        var byID: [URL: Server] = [:]
        for url in added { byID[url] = Server(adminURL: url, cliKey: nil, addedInApp: true) }
        for entry in cli.servers {
            byID[entry.adminURL, default: Server(adminURL: entry.adminURL, cliKey: nil, addedInApp: false)].cliKey = entry.apiKey
        }
        servers = byID.values.sorted { ($0.name, $0.id.absoluteString) < ($1.name, $1.id.absoluteString) }
        if let selectedID, !servers.contains(where: { $0.id == selectedID }) { self.selectedID = servers.first?.id }
        return cli.current
    }

    func select(_ id: URL) {
        guard servers.contains(where: { $0.id == id }) else { return }
        selectedID = id
        isAdding = false
        defaults.set(id.absoluteString, forKey: Self.selectedKey)
    }

    /// Add the server named by `input` and show it; false when it is not a server address.
    /// A server already in the list is only shown.
    func connect(to input: String) -> Bool {
        guard let url = ServerAddress.adminURL(from: input, allowLocalHTTP: allowLocalHTTP) else { return false }
        var added = defaults.stringArray(forKey: Self.serversKey) ?? []
        if !added.contains(url.absoluteString) { added.append(url.absoluteString) }
        defaults.set(added, forKey: Self.serversKey)
        refreshServers()
        select(url)
        return true
    }

    func startAdding() { isAdding = true }
    func cancelAdding() { isAdding = false }

    /// Removes a server added in the app. One the CLI is logged in to stays: `siteio logout` removes it.
    func remove(_ id: URL) {
        let added = (defaults.stringArray(forKey: Self.serversKey) ?? []).filter {
            ServerAddress.adminURL(from: $0, allowLocalHTTP: allowLocalHTTP) != id
        }
        defaults.set(added, forKey: Self.serversKey)
        refreshServers()
        if selected == nil {
            selectedID = servers.first?.id
            defaults.set(selectedID?.absoluteString, forKey: Self.selectedKey)
        }
    }

    func reload() { reloadToken = UUID() }

    /// The window's title: the server, for the Window menu and Mission Control.
    var windowTitle: String { selected.map { "SiteIO — \($0.name)" } ?? "SiteIO" }

    // MARK: Versions, for the footer

    /// What the footer says about the shown server's siteio.
    var footerVersion: SiteioVersion.Status {
        SiteioVersion.status(server: selectedID.flatMap { serverVersions[$0] }, latest: latestSiteio)
    }

    /// Asks the shown server which siteio it runs, and GitHub for the latest release (once).
    /// Best-effort: a failure leaves the footer without a version.
    func loadVersions(fetch: @Sendable (URL) async -> Data? = SiteioVersion.fetch) async {
        if latestSiteio == nil, let data = await fetch(SiteioVersion.latestReleaseURL) {
            latestSiteio = SiteioVersion.parseLatestRelease(data)
        }
        guard let id = selectedID, let health = URL(string: "/health", relativeTo: id)?.absoluteURL,
              let data = await fetch(health), let version = SiteioVersion.parseHealth(data) else { return }
        serverVersions[id] = version
    }
}
