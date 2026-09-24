# MissionClose

[![CI](https://github.com/beqaabu/MissionClose/actions/workflows/ci.yml/badge.svg)](https://github.com/beqaabu/MissionClose/actions/workflows/ci.yml)

Close windows straight from Mission Control on macOS.

**Website:** https://beqaabu.github.io/MissionClose

Swipe up with three fingers (or press F3 / Ctrl+↑) and hover a window thumbnail: traffic-light buttons appear in its corner.
No more opening a window just to hit its red button.

- **✕ close**: closes that window, same as its red traffic-light button
- **Option-click ✕**: quits the whole app (the ✕ turns into ⏻ while Option is held)
- **− minimize** and **⤢ full screen**: same as the yellow and green buttons
- **⌘W / ⌘Q / ⌘M** while hovering a thumbnail: close the window / quit its app / minimize it

MissionClose lives in the menu bar and starts at login. From its menu you can set:

- **Button Corner**: top left or top right of the thumbnail
- **Button Size**: small, medium or large
- **Show Buttons**: only on the hovered thumbnail, or on all of them
- **Confirm Before Quitting Apps**: the first ⌥-click / ⌘Q arms the button, a second one within 3 seconds quits
- **Launch at Login**

## Install

```sh
brew install --cask beqaabu/tap/missionclose
```

Or by hand:

1. Download `MissionClose-<version>.zip` from [Releases](../../releases), unzip it, and move `MissionClose.app` to `/Applications` or `~/Applications`.
2. Open it. MissionClose isn't signed with an Apple Developer ID, so macOS blocks it the first time:
   go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
   (Or run `xattr -dr com.apple.quarantine /path/to/MissionClose.app` before opening it.)
3. Grant **Accessibility** access when asked (**System Settings → Privacy & Security → Accessibility**).
   MissionClose needs it to see Mission Control's thumbnails, catch clicks on the ✕, and press a window's close button.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`), macOS 13 or later.

```sh
./build.sh      # builds and installs to ~/Applications/MissionClose.app
./release.sh    # also packages dist/MissionClose-<version>.zip
```

The first build creates a self-signed code signing certificate in `signing/` (git-ignored).
Signing every build with the same certificate keeps macOS from asking for Accessibility access again after each rebuild.

The app is a universal binary (Apple Silicon and Intel) for macOS 13 and later.

## Releasing

**From GitHub:** Actions → **Release** → **Run workflow**, enter a version (e.g. `0.3.0`) and an optional summary.
The workflow bumps `Info.plist`, builds and signs the app, commits the bump, tags it, and publishes a release
whose notes are the summary plus the commits since the last release.

**From the command line:** bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Info.plist`, commit, then push an annotated tag:

```sh
git tag -a v0.3.0 -m "What's new in this release"
git push origin main v0.3.0
```

Either way the [Release workflow](.github/workflows/release.yml) signs with the certificate stored in the `SIGNING_P12_BASE64`
repository secret (base64 of `signing/id.p12`), so every release has the same signature and users keep their
Accessibility permission across updates.

## How it works

macOS has no API for Mission Control, so MissionClose works from the outside:

- **Is Mission Control open?** While it's on screen, the Dock's accessibility tree contains a group with the identifier `mc`;
  its buttons are the window thumbnails, with their on-screen frames and window titles.
- **When to show the ✕.** Thumbnails animate in and out and follow your fingers during a swipe,
  so buttons only appear once no thumbnail has moved for a moment and no three-finger swipe is in progress (tracked from trackpad touch events).
- **Clicking.** Mission Control takes mouse clicks itself, so a session event tap (enabled only while Mission Control is open)
  catches clicks on a ✕ before Mission Control sees them.
- **Closing.** The thumbnail is matched to a real window by title (falling back to app name and aspect ratio),
  and that window's close button is pressed (or it's minimized / made full screen) through the accessibility API.

## Limitations

- Relies on undocumented details of how the Dock exposes Mission Control, so a macOS update could break it. Built and tested on macOS 26.
- Two windows with the same title in different apps can occasionally be confused; aspect ratio is used as a tie-breaker.
- Windows on other Spaces aren't shown in Mission Control's main view, so they can't be closed from there.

## License

MIT
