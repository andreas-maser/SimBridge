---
lang: en
---

# What SimBridge does

SimBridge mounts the file storage of your **iOS Simulator apps** as a regular location in the **macOS Finder**. Instead of digging through cryptic paths like `~/Library/Developer/CoreSimulator/Devices/<UUID>/…`, you open, edit, copy, rename, and delete the files right in the Finder — and changes appear live while SimBridge is running.

This guide walks you through everything that matters in a few minutes: granting access, mounting a location, working in the Finder, cleaning up — plus the limits and the most common snags.

# Requirements

- **macOS 14** (Sonoma) or later.
- **Xcode** with the Simulators you want to look into.
- SimBridge is installed and lives in **`/Applications`** (launch it from there — not from your Downloads folder).

# Ready in one minute

1. Open SimBridge.
2. On first launch, **grant Simulator access** (one time — see the next section).
3. Pick a Simulator on the left, click **Mount** next to a source on the right.
4. The location appears in the **Finder** under *Locations* — done.

The rest of this guide explains each step in more detail.

# Step 1 — Grant Simulator access (one time)

So SimBridge can find your Simulators, it needs your permission for the CoreSimulator folder once. This is a plain macOS security prompt; SimBridge remembers the grant.

> **How to:**
> 1. Click **Grant Simulator Access…** (or the folder button in the toolbar).
> 2. In the dialog, click the **“Devices”** folder inside **CoreSimulator** once.
> 3. Click **Grant Access**.

The sidebar now shows your Simulators. You only do this once.

Don’t see any Simulators? Start a Simulator in Xcode, install/open your app there, and click **Refresh** in SimBridge.

# Step 2 — Mount a location

Pick a Simulator on the left. On the right you’ll see up to three **source types** — depending on where the files you’re after actually live:

- **App data** — your app’s container: `Documents`, `Library`, `tmp`. Most of what your app saves itself ends up here.
- **App Group** — the app’s shared storage, e.g. a **SwiftData database** (`default.store`) or files shared between the app and its extensions.
- **On My iPhone** — the local “On My iPhone” storage that the iOS Files app shows.

> **How to:**
> 1. Select a Simulator on the left.
> 2. Click **Mount** next to the source you want.
> 3. The location appears in the Finder under *Locations* and in SimBridge under **Mounted**.

A tip if you’re hunting for a file and can’t find it: what the iOS Files app shows under “On My iPhone” often is **not** in the app’s `Documents`, but in the local storage or the App Group. When in doubt, try all three source types.

# Step 3 — Work in the Finder

A mounted location behaves like any other Finder folder. You can:

- **open and view** files and folders,
- **edit** contents (changes go straight into the Simulator),
- **create** new files and folders,
- **rename**, **move**, and **delete**,
- drag & drop files **in and out**.

This lets you, for example, quickly drop a prepared test file into the app container, copy out a SwiftData database for inspection, or delete a broken preferences file.

# Live updates

Files your **running app** creates or changes appear in the Finder automatically — **as long as SimBridge stays open**. You don’t need to refresh; the location keeps itself up to date.

Deeply nested changes refresh as soon as you (re)open the folder in question in the Finder.

# Working from the menu bar

SimBridge lives in the **menu bar**. You can close the main window — the app keeps running so live updates don’t stop. From the menu-bar item you can reopen the main window anytime and see at a glance what’s currently mounted.

# Show only running Simulators

If you’ve created many Simulators, the list gets long. The **Only running** toggle in the toolbar hides all stopped Simulators and shows just the one you’re working with.

# Removing locations & cleaning up

Take a single location back out of the Finder with **Remove** (the files inside the Simulator stay untouched of course — only the Finder location is unregistered).

The **“…” menu** at the top right has two cleanup actions:

- **Remove Unavailable Locations** — clears locations whose Simulator or app no longer exists (e.g. because you deleted the Simulator). Such locations are dimmed and marked with a warning icon in the list.
- **Remove All Finder Locations…** — unregisters every SimBridge location at once. Handy if something ever gets stuck. You can always mount again afterwards.

# What SimBridge does not do — the limits

- **Simulators only, no real devices.** The files of a physical iPhone can’t be surfaced the same way, technically. For devices, keep using Xcode or `xcrun devicectl` in the Terminal.
- **Not a Mac App Store app.** SimBridge reaches into Xcode’s CoreSimulator folder — which is incompatible with App Store rules. That’s why it’s distributed outside the store (signed and notarized) so macOS trusts it.

# When something gets stuck

**No Simulators or apps shown.** Start a Simulator in Xcode, install/open your app there, and click **Refresh** in SimBridge. Also check that access is granted (Step 1).

**The location appears, but nothing loads.** Enable the location in the **Finder** — depending on your macOS version you may need to switch it on once in the Finder sidebar or Finder settings. It then shows its contents.

**A location is dimmed (“Unavailable”).** Its Simulator or app no longer exists. Get rid of it via **“…” → Remove Unavailable Locations**.

**A location is stuck and won’t remove.** Use **“…” → Remove All Finder Locations…** and mount again afterwards.

# Symbols at a glance

- **Bolt** — the *Only running* toggle: shows only started Simulators.
- **Folder with gear** — grant or change Simulator access.
- **Circular arrow** — Refresh: rescan Simulators and locations.
- **Blue app tile** — App data (Documents/Library/tmp).
- **Purple box tile** — App Group (e.g. a SwiftData database).
- **Teal drive tile** — On My iPhone (local storage).
- **Green dot** — the Simulator is currently running.

You’ll find the same legend anytime inside the app under **Help** (⌘?).

# In short

Grant access once, mount a source, work in the Finder — that’s all there is to it. SimBridge turns tedious path-digging into a double-click in the sidebar. Happy building.
