import Foundation

/// What matching needs to know about a window, with no accessibility objects involved so the rules
/// can be tested on their own. `liveTitle` is re-read at match time; `title` was cached when
/// Mission Control opened, and the two differ for windows whose title changes (a terminal spinner,
/// a document marked edited).
struct WindowCandidate {
    let title: String
    let liveTitle: String
    let appName: String
    let size: CGSize

    init(title: String, liveTitle: String? = nil, appName: String = "", size: CGSize = .zero) {
        self.title = title
        self.liveTitle = liveTitle ?? title
        self.appName = appName
        self.size = size
    }
}

enum WindowMatching {
    /// Mission Control labels a thumbnail with the window's title, or the app's name when a window has
    /// none. Returns the index of the best candidate, or nil when nothing plausibly matches.
    ///
    /// Rules are tried in order of confidence; ties are broken by whichever window's shape is closest
    /// to the thumbnail's.
    static func bestMatch(label: String, thumbnailAspect: CGFloat, in candidates: [WindowCandidate]) -> Int? {
        guard !label.isEmpty else { return nil }
        let rules: [(WindowCandidate) -> Bool] = [
            { $0.title == label },
            { $0.liveTitle == label },
            // Some apps put more in the title bar than Mission Control shows,
            // e.g. Preview's "photo.png – 2 documents, 2 total pages".
            { $0.title.hasPrefix(label) },
            { $0.liveTitle.hasPrefix(label) },
            // ...and the reverse: a label that carries a suffix the window's own title doesn't.
            { !$0.title.isEmpty && label.hasPrefix($0.title) },
            { !$0.appName.isEmpty && $0.appName == label },
        ]
        for rule in rules {
            let matches = candidates.indices.filter { rule(candidates[$0]) }
            guard !matches.isEmpty else { continue }
            return matches.min { closeness(candidates[$0], thumbnailAspect) < closeness(candidates[$1], thumbnailAspect) }
        }
        return nil
    }

    private static func closeness(_ candidate: WindowCandidate, _ thumbnailAspect: CGFloat) -> CGFloat {
        abs(candidate.size.width / max(candidate.size.height, 1) - thumbnailAspect)
    }
}
