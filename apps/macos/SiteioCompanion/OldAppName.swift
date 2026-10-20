import Foundation

/// The app was called "siteio Companion.app" before it became "SiteIO.app".
/// Sparkle installs each update under the old file name, and the pkg installs
/// the new name next to the old one. At launch, the running app removes the
/// other copy next to it and takes the new name. (As AgentIO's OldAppName.)
enum OldAppName {
    static let oldName = "siteio Companion.app"
    static let newName = "SiteIO.app"

    enum Outcome: Equatable, Sendable {
        /// Nothing to do, or a step failed (no rights on the folder, for example).
        case unchanged
        /// The other copy went away; the app keeps running.
        case removedOther
        /// The app now lives at this URL; it must start again from there.
        case renamed(URL)
    }

    /// Only a copy with `bundleID` is removed or replaced, never another app with the same
    /// file name. `discard` moves a copy away; by default, to the Trash.
    static func tidy(
        bundle: URL,
        bundleID: String,
        fileManager: FileManager = .default,
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) -> Outcome {
        let name = bundle.lastPathComponent
        guard name == oldName || name == newName else { return .unchanged }
        let folder = bundle.deletingLastPathComponent()
        let other = folder.appending(path: name == oldName ? newName : oldName, directoryHint: .isDirectory)
        var outcome = Outcome.unchanged
        if Bundle(url: other)?.bundleIdentifier == bundleID, (try? discard(other)) != nil {
            outcome = .removedOther
        }
        guard name == oldName else { return outcome }
        let renamed = folder.appending(path: newName, directoryHint: .isDirectory)
        guard (try? fileManager.moveItem(at: bundle, to: renamed)) != nil else { return outcome }
        return .renamed(renamed)
    }
}
