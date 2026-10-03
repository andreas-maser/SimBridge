# SimBridge

**Browse the file storage of your iOS Simulator apps right in the macOS Finder.**

SimBridge mounts the sandbox of any app in your iOS Simulators as a regular location in the Finder sidebar — so you can read, open, edit, add, rename, move, and delete files just like in any other folder, with live updates while the app runs.

It's built for developers who constantly need to peek into (or drop files into) a Simulator app's `Documents`, its App Group container, or the local "On My iPhone" storage — without digging through the cryptic `~/Library/Developer/CoreSimulator/Devices/<UDID>/…` tree by hand.

---

## Why

Inspecting a Simulator app's files usually means either copy-pasting long UUID paths into Terminal or fishing around in Finder's "Go to Folder". SimBridge turns those containers into first-class Finder locations that update themselves, so the files are simply *there* when you need them.

## Features

- **Automatic discovery** of your Simulators and their installed apps (reads the CoreSimulator tree directly — no `simctl` calls needed).
- **Three mountable sources per app:** the app data container (`Documents`, `Library`, `tmp`), matching **App Group** containers (e.g. a SwiftData store), and the local **"On My iPhone"** file storage.
- **Full read/write** in the Finder: open, edit, create, rename, move, delete.
- **Live updates** — files the running app writes appear automatically while SimBridge is open.
- **Menu-bar app** so it can keep syncing in the background.
- **"Only running" filter** to hide stopped Simulators.
- **Localized** in English, German, and Spanish, with an in-app Help window.
- **Recovery tools** for stale/orphaned Finder locations (deleted Simulators, etc.).

## How it works (in one paragraph)

A macOS **File Provider extension** serves each mounted folder to the Finder. The app does the "worldly" work — finding Simulators/apps and registering domains — while the sandboxed extension reads the container files directly via a temporary-exception entitlement. The mount's root path is encoded into the File Provider domain identifier itself, which sidesteps the extension's persona isolation: it cannot read files or `UserDefaults` that the app writes into the shared container, so the identifier has to carry everything the extension needs.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+ with the iOS Simulators you want to browse
- An Apple Developer account (for the App Group and code signing)

## Install

Grab a signed, notarized build from the **[Releases page](https://github.com/andreas-maser/SimBridge/releases)**, drag **SimBridge.app** to `/Applications`, and launch it. On first launch, click **Open** in the "downloaded from the internet" prompt — the app is notarized, so there's no unidentified-developer block.

Via Homebrew:

```bash
brew install --cask andreas-maser/tap/simbridge
```

### Build from source

```bash
git clone https://github.com/andreas-maser/SimBridge.git
```

1. Open `SimBridge.xcodeproj` in Xcode.
2. Set **your** Development Team on both the **SimBridge** and **SimBridgeFileProvider** targets. The checked-in project ships with an empty team on purpose, so Xcode asks you instead of failing with someone else's identifier.
3. Create an App Group that both targets share, and enter it in `SimBridge/SimBridge.entitlements` and in the extension's `Info.plist`. The app and the extension exchange a security-scoped bookmark through it; without a shared group, nothing mounts.
4. Build & run the **SimBridge** scheme.

## Usage

1. On first launch, click **Grant Simulator Access…** and select the **`Devices`** folder inside `CoreSimulator` (one time only).
2. Pick a Simulator in the sidebar, then **Mount** a source next to it.
3. The location appears in the Finder sidebar under **Locations** — browse and edit away.
4. **Remove** takes it back out. Open the in-app **Help** (⌘?) for a symbol legend and tips.

The full user guide is in this repository: **[English](Dokumentation/Anwenderhandbuch/SimBridge_UserGuide_EN.pdf)** · **[Deutsch](Dokumentation/Anwenderhandbuch/SimBridge_Anwenderhandbuch_DE.pdf)**. It also covers the common failure cases — stuck locations, orphaned domains, "can't be used right now".

## Testing note (important)

File Provider extensions behave differently under the Xcode debugger. In a **Debug** build, the extension is wrapped in a debug dylib that only the debugger can launch, so mounting works but **removing a location fails** with *"the application can't be used right now"*, and launching outside Xcode won't mount at all.

To test the real behaviour, run a **Release** build as a normally installed app: build in Release, copy `SimBridge.app` to `/Applications`, and launch it from there — not from Xcode. That is exactly how the app ships.

One more thing worth knowing: if the extension crashes three times in a row, Launch Services stops launching it until the app is reinstalled or the system is restarted. A crash loop therefore looks like "mounting silently does nothing".

## Limitations

- **Not a Mac App Store app — by decision.** SimBridge reaches into CoreSimulator via a temporary-exception entitlement. That is fine for Developer-ID distribution and incompatible with App Store review. Rather than cut the feature to fit the Store, the app is given away: free, here and through Homebrew.
- **Simulators only, for now.** Physical iOS devices are not supported: `xcrun devicectl` cannot run inside the app sandbox, so real-device support would need a separate non-sandboxed helper (SMAppService). Left as a possible future addition.
- **Deep nested live updates** refresh when the containing folder is (re)opened; the top level of a mount updates automatically.

## Contributing

Issues and pull requests are welcome. The tricky, testable core logic — identifier mapping, directory reading — lives in the `SimBridgeKit` Swift package with its own unit tests. That is a good place to start.

## License

[MIT](LICENSE) © 2026 Andreas Maser · [devForPeople](https://devforpeople.de)
