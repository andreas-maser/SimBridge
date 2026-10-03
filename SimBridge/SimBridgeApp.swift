//
//  SimBridgeApp.swift
//  SimBridge
//
//  Created for SimBridge.
//

import SwiftUI

@main
struct SimBridgeApp: App {

    /// Single, app-lifetime model so the live-update watcher keeps running even
    /// when the main window is closed (menu-bar app behaviour).
    @State private var model = MountsModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .commands { HelpCommands() }

        Window("SimBridge Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)

        MenuBarExtra("SimBridge", image: "MenuBarIcon") {
            MenuBarView()
                .environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Replaces the default Help menu with a link to SimBridge’s own help window.
private struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("SimBridge Help") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
