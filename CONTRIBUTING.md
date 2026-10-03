# Contributing

Thanks for taking a look. Bug reports about apps whose windows MissionClose can't identify are
especially useful, since matching thumbnails to windows is the fiddliest part.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`) and macOS 13 or later. There's no Xcode
project and no dependencies; `swiftc` builds it directly.

```sh
./build.sh                 # universal build, installs to ~/Applications/MissionClose.app
ADHOC=1 NO_INSTALL=1 ./build.sh   # what CI runs
./release.sh               # also packages dist/MissionClose-<version>.zip
```

The first build creates a self-signed code signing certificate in `signing/` (git-ignored). Signing every
build with the same certificate keeps its designated requirement stable, so macOS doesn't drop the
Accessibility permission after each rebuild. Ad-hoc signatures change every time, which does.

## Code layout

| File | What's in it |
| --- | --- |
| `Sources/AX.swift` | Thin wrappers over the accessibility API, and AX ↔ Cocoa coordinate conversion |
| `Sources/MissionControl.swift` | Finding Mission Control in the Dock's (macOS 27: WindowManager's) accessibility tree and its thumbnails |
| `Sources/WindowIndex.swift` | Every on-screen window, gathered through the accessibility API |
| `Sources/WindowMatching.swift` | The rules that decide which window a thumbnail belongs to (unit-tested) |
| `Sources/Welcome.swift` | First-run window explaining the Accessibility requirement |
| `Sources/UpdateCheck.swift` | The on-demand "Check for Updates" request |
| `Sources/WindowButtons.swift` | The floating traffic-light buttons and their drawing |
| `Sources/Controller.swift` | The polling loop, event taps, hover state and the actions |
| `Sources/Settings.swift` | Preferences, stored in UserDefaults |
| `Sources/MenuBarIcon.swift` | The menu bar icon, drawn in code as a template image |
| `Sources/main.swift` | App delegate and menu |
| `tools/` | The scripted demo driver used for recordings |
| `site/` | The website, deployed to GitHub Pages on every change |

## Tests

```sh
./tools/test.sh
```

Plain assertions, no XCTest, so the project stays buildable with `swiftc` alone. They cover the rules
that decide which window a thumbnail belongs to (`Sources/WindowMatching.swift`) and version comparison.
CI runs them on every push.

## Recording a demo

```sh
./tools/record-demo.sh                 # opens its own windows, counts down, then drives Mission Control
./tools/record-demo.sh --countdown 20  # more time to start recording
./tools/record-demo.sh --diagnose      # log what each app allows, no recording
./tools/record-demo.sh --build-only
```

The driver launches copies of itself as helper apps showing mock documents, so recordings never contain
real apps or private content. It needs its own Accessibility grant: it's built as an app bundle because a
command-line tool started from a terminal inherits the terminal's grant instead of having its own.

## Releasing

**From GitHub:** Actions → **Release** → **Run workflow**, enter a version (e.g. `0.3.0`) and an optional
summary. The workflow bumps `Info.plist`, builds and signs, commits the bump, tags it, and publishes the
release. The notes are the summary plus the commits since the last release.

**From the command line:** bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, commit,
then push an annotated tag whose message becomes the release notes:

```sh
git tag -a v0.3.0 -m "What's new in this release"
git push origin main v0.3.0
```

Either way the [Release workflow](.github/workflows/release.yml) signs with the certificate in the
`SIGNING_P12_BASE64` secret, so every release carries the same signature and users keep their Accessibility
permission across updates. It then updates the [Homebrew cask](https://github.com/beqaabu/homebrew-tap)
using the `HOMEBREW_TAP_TOKEN` secret.

**Keep a backup of `signing/id.p12`.** GitHub secrets can't be read back, and losing it means every user
has to grant Accessibility again after the next update.

## Notes for changes

- The app must stay silent when Mission Control is closed: the click tap is disabled and polling drops to
  10 times a second. Anything heavier is a regression.
- Don't tap event type 30 (the Dock's private swipe events). Any tap on it, even listen-only, breaks
  the auto-hidden Dock's hover reveal.
- Mission Control and App Exposé appear in the Dock's accessibility tree as `mc` and `appexpose`, with the
  same layout. `tools/record-demo.sh --watch-expose` dumps that tree while you trigger an overview by hand,
  which is how new macOS versions can be checked.
- CI builds every push and pull request on a macOS runner, so keep the build free of Xcode-only steps.
