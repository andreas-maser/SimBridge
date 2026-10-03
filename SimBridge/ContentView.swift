//
//  ContentView.swift
//  SimBridge
//
//  Created for SimBridge.
//

import SwiftUI
import SimBridgeKit

/// Control center: a macOS sidebar of Simulators + a "Mounted" item, with a
/// detail list of mountable sources (app data, app groups, local storage).
struct ContentView: View {

    @Environment(MountsModel.self) private var model
    @AppStorage("simbridge.showOnlyBooted") private var showOnlyBooted = false
    @State private var selection: Selection? = .mounted
    @State private var showResetConfirm = false

    enum Selection: Hashable {
        case mounted
        case device(String)   // simulator device UDID
    }

    private typealias DeviceGroup = MountsModel.DeviceGroup

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showOnlyBooted) {
                    Label("Only running", systemImage: "bolt.fill")
                }
                .toggleStyle(.button)
                .help("Show only running simulators")
            }
            // Visually separate the filter toggle from the actions so macOS 26
            // groups them into distinct Liquid Glass toolbar clusters. Pure
            // cosmetics, so it's gated to the systems that have it.
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Choose Simulator Folder…", systemImage: "folder.badge.gearshape") {
                    model.requestSimulatorAccess()
                }
                .help("Grant or change access to the CoreSimulator folder")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.reload()
                    model.discover()
                }
                .help("Rescan simulators and mounts")
            }
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Remove Unavailable Locations") {
                        model.removeUnavailableMounts()
                    }
                    .disabled(!model.hasUnavailableMounts)
                    Divider()
                    Button("Remove All Finder Locations…", role: .destructive) {
                        showResetConfirm = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .help("Recovery actions")
            }
        }
        .confirmationDialog(
            "Remove all Finder locations?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) { model.resetAllMounts() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This unmounts every SimBridge location from the Finder. Use it to recover from stuck locations. You can mount them again afterwards.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                Label {
                    Text("Mounted")
                } icon: {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .foregroundStyle(.blue)
                }
                .badge(model.mounts.count)   // native count; auto-hides when zero
                .tag(Selection.mounted)
            }

            if model.hasSimulatorAccess {
                Section("Simulators") {
                    ForEach(deviceGroups) { group in
                        deviceRow(group).tag(Selection.device(group.udid))
                    }
                }
            }
        }
        .navigationTitle("SimBridge")
        .navigationSplitViewColumnWidth(min: 230, ideal: 260)
    }

    private func deviceRow(_ group: DeviceGroup) -> some View {
        HStack(spacing: 8) {
            Image(systemName: deviceSymbol(group.name))
                .font(.system(size: 16))
                .foregroundStyle(group.isBooted ? Color.green : Color.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                Text(group.runtime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if group.isBooted {
                Circle().fill(.green).frame(width: 7, height: 7)
                    .help("running")
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if !model.hasSimulatorAccess {
            accessPlaceholder
        } else if selection == .mounted {
            mountedDetail
        } else if case let .device(udid) = selection,
                  let group = deviceGroups.first(where: { $0.udid == udid }) {
            deviceDetail(group)
        } else {
            ContentUnavailableView(
                "Nothing selected",
                systemImage: "sidebar.left",
                description: Text("Select a simulator or “Mounted” on the left.")
            )
        }
    }

    private var accessPlaceholder: some View {
        ContentUnavailableView {
            Label("Simulator Access Required", systemImage: "lock.shield")
        } description: {
            Text("Grant SimBridge one-time access to the CoreSimulator folder to find your simulators and apps.")
        } actions: {
            Button("Grant Simulator Access…") {
                model.requestSimulatorAccess()
            }
            .prominentActionButtonStyle()
        }
    }

    private func deviceDetail(_ group: DeviceGroup) -> some View {
        List {
            ForEach(group.items) { item in
                sourceRow(item)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(group.name)
        .navigationSubtitle(group.isBooted ? Text("\(group.runtime) · running") : Text(group.runtime))
        .overlay { errorBanner }
    }

    @ViewBuilder
    private var mountedDetail: some View {
        Group {
            if model.mounts.isEmpty {
                ContentUnavailableView(
                    "Nothing mounted yet",
                    systemImage: "externaldrive.badge.plus",
                    description: Text("Select a simulator on the left and mount a source.")
                )
            } else {
                List {
                    ForEach(model.mounts, id: \.domainIdentifier) { mount in
                        mountRow(mount)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Mounted")
        .overlay { errorBanner }
    }

    // MARK: - Rows

    private func sourceRow(_ item: SimulatorMountable) -> some View {
        let isMounted = model.mountedDomainIdentifiers.contains(model.domainIdentifier(for: item))
        return HStack(spacing: 12) {
            iconTile(symbol: symbol(for: item.kind), color: color(for: item.kind))
                .help(kindHelp(item.kind))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(item.title))
                Text(LocalizedStringKey(item.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isMounted {
                Label("Mounted", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .help("Already mounted in Finder")
            } else {
                Button("Mount") { model.mount(item) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func mountRow(_ mount: MountDescriptor) -> some View {
        let available = model.isAvailable(mount)
        return HStack(spacing: 12) {
            iconTile(
                symbol: available ? "externaldrive.fill" : "externaldrive.trianglebadge.exclamationmark",
                color: available ? .blue : .orange
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(mount.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !available {
                    Text("Unavailable — the simulator or app no longer exists")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            Button("Remove", role: .destructive) { model.unmount(mount) }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .opacity(available ? 1 : 0.7)
        .help(available ? Text(verbatim: mount.displayName)
                        : Text("The simulator or app for this location no longer exists."))
        .contextMenu {
            Button("Remove", role: .destructive) { model.unmount(mount) }
        }
    }

    private func iconTile(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = model.errorMessage {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error).font(.callout)
                    Spacer()
                    Button("OK") { model.errorMessage = nil }
                        .buttonStyle(.borderless)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.red.opacity(0.4)))
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func deviceSymbol(_ name: String) -> String {
        if name.localizedCaseInsensitiveContains("watch") { return "applewatch" }
        if name.localizedCaseInsensitiveContains("ipad") { return "ipad" }
        if name.localizedCaseInsensitiveContains("tv") { return "appletv" }
        return "iphone"
    }

    private func symbol(for kind: SimulatorMountable.Kind) -> String {
        switch kind {
        case .appData: "app.fill"
        case .appGroup: "shippingbox.fill"
        case .localStorage: "internaldrive.fill"
        }
    }

    private func color(for kind: SimulatorMountable.Kind) -> Color {
        switch kind {
        case .appData: .blue
        case .appGroup: .purple
        case .localStorage: .teal
        }
    }

    private func kindHelp(_ kind: SimulatorMountable.Kind) -> LocalizedStringKey {
        switch kind {
        case .appData: "The app’s container (Documents, Library, tmp)"
        case .appGroup: "Shared storage, e.g. a SwiftData database"
        case .localStorage: "Local “On My iPhone” files"
        }
    }

    // MARK: - Grouping

    /// Device groups for display. The heavy grouping/sort is cached in the model;
    /// here we only apply the lightweight "only running" filter.
    private var deviceGroups: [DeviceGroup] {
        showOnlyBooted ? model.deviceGroups.filter(\.isBooted) : model.deviceGroups
    }
}

private extension View {
    /// Prominent style for the app's single primary call to action: the modern
    /// Liquid Glass style on macOS 26+, falling back to the bordered-prominent
    /// style on earlier systems.
    @ViewBuilder
    func prominentActionButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environment(MountsModel())
}
