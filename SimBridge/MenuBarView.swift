//
//  MenuBarView.swift
//  SimBridge
//
//  Created for SimBridge.
//

import SwiftUI
import AppKit
import SimBridgeKit

/// Compact, modern popover shown from the menu-bar item: mounted locations plus
/// quick actions. The full mounting UI lives in the main window.
struct MenuBarView: View {

    @Environment(MountsModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().padding(.vertical, 8)

            mounts

            Divider().padding(.vertical, 8)

            MenuActionRow(title: "Mount Locations…", systemImage: "plus.circle.fill", tint: .blue) {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            MenuActionRow(title: "Refresh", systemImage: "arrow.clockwise") {
                model.reload()
                model.discover()
            }
            MenuActionRow(title: "SimBridge Help", systemImage: "questionmark.circle") {
                openWindow(id: "help")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider().padding(.vertical, 8)

            MenuActionRow(title: "Quit SimBridge", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 320)
    }

    private var headerSubtitle: LocalizedStringKey {
        model.mounts.isEmpty ? "No locations mounted" : "\(model.mounts.count) in Finder"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.blue.gradient)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("SimBridge").font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Live").font(.caption2).foregroundStyle(.secondary)
            }
            .help("Live update active while SimBridge is running")
        }
    }

    // MARK: - Mounts

    @ViewBuilder private var mounts: some View {
        if model.mounts.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "tray").foregroundStyle(.secondary)
                Text("Nothing mounted").font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        } else {
            VStack(spacing: 2) {
                ForEach(model.mounts, id: \.domainIdentifier) { mount in
                    MountRow(mount: mount) { model.unmount(mount) }
                }
            }
        }
    }
}

// MARK: - Rows

private struct MountRow: View {
    let mount: MountDescriptor
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.blue.gradient)
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(mount.displayName)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.3)
            .help("Remove")
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.06) : .clear))
        .onHover { hovering = $0 }
    }
}

private struct MenuActionRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint: Color = .secondary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(title).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.06) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

#Preview {
    MenuBarView()
        .environment(MountsModel())
}
