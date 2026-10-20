import Foundation

/// The servers the siteio CLI is logged in to, read from its config file
/// (`~/.config/siteio/config.json`, written by `siteio login`):
///
///     { "current": "example.com", "servers": { "example.com": { "apiUrl": "https://api.example.com", "apiKey": "…" } } }
///
/// The app only reads the file. Keys stay in memory: they open the admin page signed in,
/// as `siteio ui` does, and are never stored by the app.
enum CLIServers {
    struct Entry: Equatable, Sendable {
        let adminURL: URL
        let apiKey: String
    }

    static var defaultFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/siteio/config.json")
    }

    /// The usable servers, and the admin page of the CLI's current server when it is one of them.
    /// A missing, unreadable or malformed file gives none; a malformed entry is skipped.
    static func read(_ file: URL, allowLocalHTTP: Bool) -> (servers: [Entry], current: URL?) {
        // The file holds a few servers; anything far larger is not the CLI's.
        guard let data = try? Data(contentsOf: file), data.count <= 1_000_000,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["servers"] as? [String: Any]
        else { return ([], nil) }

        var entries: [Entry] = []
        var current: URL?
        for (domain, value) in servers {
            guard let server = value as? [String: Any],
                  let apiUrl = server["apiUrl"] as? String,
                  let apiKey = server["apiKey"] as? String, isKey(apiKey),
                  // The CLI always writes a full URL: never guess a host from a bare name.
                  apiUrl.range(of: "://") != nil,
                  let adminURL = ServerAddress.adminURL(from: apiUrl, allowLocalHTTP: allowLocalHTTP)
            else { continue }
            guard !entries.contains(where: { $0.adminURL == adminURL }) else { continue }
            entries.append(Entry(adminURL: adminURL, apiKey: apiKey))
            if domain == json["current"] as? String { current = adminURL }
        }
        entries.sort { $0.adminURL.absoluteString < $1.adminURL.absoluteString }
        return (entries, current)
    }

    /// One line of printable ASCII, no spaces: what siteio's keys look like.
    private static func isKey(_ key: String) -> Bool {
        (1...4096).contains(key.count) && key.unicodeScalars.allSatisfy { $0.isASCII && $0.value > 0x20 && $0.value < 0x7F }
    }

    /// The admin page that signs in with `key`: `/ui?key=…`, read and then removed from the
    /// address by the page itself. Everything but unreserved characters is percent-encoded,
    /// so a `+`, `&` or `#` in a key reaches the page as written.
    static func signedInURL(_ adminURL: URL, key: String) -> URL {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var components = URLComponents(url: adminURL, resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = "key=" + key.addingPercentEncoding(withAllowedCharacters: unreserved)!
        return components.url!
    }
}
