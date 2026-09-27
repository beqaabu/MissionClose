import Cocoa

/// Checks GitHub for a newer release. Only ever runs when the menu item is clicked: MissionClose
/// makes no network connections on its own.
enum UpdateCheck {
    private static let latestAPI = URL(string: "https://api.github.com/repos/beqaabu/MissionClose/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/beqaabu/MissionClose/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static func run() {
        var request = URLRequest(url: latestAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MissionClose/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else {
                    return show(title: "Couldn't check for updates",
                                message: error?.localizedDescription ?? "GitHub didn't return a release.",
                                showDownload: false)
                }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                if isNewer(latest, than: currentVersion) {
                    show(title: "MissionClose \(latest) is available",
                         message: "You have \(currentVersion). Updates keep your settings and permissions.",
                         showDownload: true)
                } else {
                    show(title: "You're up to date",
                         message: "MissionClose \(currentVersion) is the latest version.",
                         showDownload: false)
                }
            }
        }.resume()
    }

    /// Compares dotted numeric versions: 0.10.0 is newer than 0.9.9.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func show(title: String, message: String, showDownload: Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: showDownload ? "Download" : "OK")
        if showDownload { alert.addButton(withTitle: "Later") }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn && showDownload {
            NSWorkspace.shared.open(releasesPage)
        }
    }
}
