import Foundation

/// The siteio a server runs, against siteio's latest release, for the footer.
enum SiteioVersion {
    enum Status: Equatable, Sendable {
        case unknown
        case version(String)
        case upToDate(String)
        case updateAvailable(current: String, latest: String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/plosson/siteio/releases/latest")!

    static func status(server: String?, latest: String?) -> Status {
        guard let server else { return .unknown }
        guard let latest, let order = compare(server, latest) else { return .version(server) }
        return order == .orderedAscending ? .updateAvailable(current: server, latest: latest) : .upToDate(server)
    }

    /// `X.Y.Z` numbers, a leading `v` allowed; nil when either is not one.
    static func compare(_ a: String, _ b: String) -> ComparisonResult? {
        guard let x = parts(a), let y = parts(b) else { return nil }
        for (l, r) in zip(x, y) where l != r { return l < r ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }

    /// The agent's `/health`: `{ "success": true, "data": { "status": "ok", "version": "1.50.1" } }`.
    static func parseHealth(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = json["data"] as? [String: Any], let version = body["version"] as? String,
              parts(version) != nil else { return nil }
        return version
    }

    /// GitHub's latest release: its `tag_name`, `v1.50.1`, without the `v`.
    static func parseLatestRelease(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String, parts(tag) != nil else { return nil }
        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    @Sendable static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("SiteIO", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_000_000 else { return nil }
        return data
    }

    private static func parts(_ text: String) -> [Int]? {
        let bare = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let numbers = bare.split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3, numbers.allSatisfy({ (1...9).contains($0.count) && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }) else { return nil }
        return numbers.compactMap { Int($0) }
    }
}
