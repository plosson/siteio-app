import Foundation

/// What a person types to name their siteio server, turned into the admin page's URL.
///
/// `sitedebile.fr`, `api.sitedebile.fr`, `https://api.sitedebile.fr` and
/// `https://api.sitedebile.fr/ui#/services` all give `https://api.sitedebile.fr/ui`:
/// a bare domain is the agent's base domain, whose API (and admin) is on `api.`.
/// An address with a scheme is taken as written, apart from its path.
enum ServerAddress {
    /// The admin page, or nil when the input is not a server address. Plain http is
    /// only for this Mac (`localhost`, `127.0.0.1`, `[::1]`) and only when `allowLocalHTTP`.
    static func adminURL(from input: String, allowLocalHTTP: Bool) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2048,
              !text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) })
        else { return nil }

        let hasScheme = text.range(of: "://") != nil
        guard let parsed = URLComponents(string: hasScheme ? text : "https://" + text),
              let scheme = parsed.scheme?.lowercased(),
              var host = parsed.host?.lowercased(), !host.isEmpty,
              parsed.user == nil, parsed.password == nil
        else { return nil }

        // This Mac is only reached by a full address (`http://localhost:3000`), never a bare name.
        let local = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
        if local && !hasScheme { return nil }
        switch scheme {
        case "https": break
        case "http" where local && allowLocalHTTP: break
        default: return nil
        }
        guard local || isDomainName(host) else { return nil }
        if !hasScheme && !local && !host.hasPrefix("api.") { host = "api." + host }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = parsed.port
        components.path = "/ui"
        return components.url
    }

    /// Two or more dot-separated labels of letters, digits and inner hyphens; no IP literals.
    private static func isDomainName(_ host: String) -> Bool {
        guard host.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.last.map({ $0.contains(where: \.isLetter) }) == true else { return false }
        return labels.allSatisfy { label in
            (1...63).contains(label.count)
                && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
                && label.first != "-" && label.last != "-"
        }
    }
}
