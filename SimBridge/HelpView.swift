//
//  HelpView.swift
//  SimBridge
//
//  Created for SimBridge.
//

import SwiftUI

/// A simple, localized help window. Content is embedded per language (English
/// fallback) and rendered from lightweight Markdown (headings, paragraphs,
/// bullets, inline bold/code).
struct HelpView: View {

    private let blocks: [HelpBlock] = HelpContent.blocks(for: Locale.current)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    switch block.kind {
                    case .title:
                        Text(block.text).font(.largeTitle.bold())
                    case .heading:
                        Text(block.text).font(.title3.bold()).padding(.top, 10)
                    case .paragraph:
                        Text(block.text).font(.body)
                    case .bullet:
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(block.text).font(.body)
                        }
                    }
                }

                symbolsSection
            }
            .padding(28)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 480, idealHeight: 620)
    }

    private var symbolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Symbols").font(.title3.bold()).padding(.top, 10)
            ForEach(SymbolLegend.all) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: entry.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(entry.color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.title).font(.body.weight(.semibold))
                        Text(entry.detail).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct SymbolLegend: Identifiable {
    let id = UUID()
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    static let all: [SymbolLegend] = [
        .init(symbol: "bolt.fill", color: .gray, title: "Only running",
              detail: "Show only running simulators"),
        .init(symbol: "folder.badge.gearshape", color: .gray, title: "Choose Simulator Folder…",
              detail: "Grant or change access to the CoreSimulator folder"),
        .init(symbol: "arrow.clockwise", color: .gray, title: "Refresh",
              detail: "Rescan simulators and mounts"),
        .init(symbol: "app.fill", color: .blue, title: "App data",
              detail: "The app’s container (Documents, Library, tmp)"),
        .init(symbol: "shippingbox.fill", color: .purple, title: "App Group",
              detail: "Shared storage, e.g. a SwiftData database"),
        .init(symbol: "internaldrive.fill", color: .teal, title: "On My iPhone",
              detail: "Local “On My iPhone” files"),
        .init(symbol: "circle.fill", color: .green, title: "Running",
              detail: "The simulator is currently booted")
    ]
}

struct HelpBlock: Identifiable {
    enum Kind { case title, heading, paragraph, bullet }
    let id = UUID()
    let kind: Kind
    let text: AttributedString
}

/// Embedded, localized help content + a tiny Markdown block parser.
enum HelpContent {

    static func blocks(for locale: Locale) -> [HelpBlock] {
        parse(markdown(for: locale))
    }

    private static func markdown(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "de": return german
        case "es": return spanish
        default:   return english
        }
    }

    // MARK: - Parser

    private static func inline(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }

    private static func parse(_ markdown: String) -> [HelpBlock] {
        var blocks: [HelpBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(HelpBlock(kind: .paragraph, text: inline(paragraph.joined(separator: " "))))
            paragraph.removeAll()
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("## ") {
                flushParagraph()
                blocks.append(HelpBlock(kind: .heading, text: inline(String(line.dropFirst(3)))))
            } else if line.hasPrefix("# ") {
                flushParagraph()
                blocks.append(HelpBlock(kind: .title, text: inline(String(line.dropFirst(2)))))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                blocks.append(HelpBlock(kind: .bullet, text: inline(String(line.dropFirst(2)))))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return blocks
    }

    // MARK: - Content

    private static let english = """
    # SimBridge

    SimBridge mounts the file storage of your iOS Simulator apps as locations in the macOS Finder — so you can browse, open, edit, add and delete files just like any other folder.

    ## Getting started

    The first time, grant SimBridge access to your Simulator folder:

    - Click **Grant Simulator Access…** (or the folder button in the toolbar).
    - In the dialog, select the **“Devices”** folder inside **CoreSimulator** and click **Grant Access**.

    SimBridge remembers this, so you only do it once.

    ## Mounting a source

    Pick a simulator in the sidebar, then click **Mount** next to a source:

    - **App data** — the app’s container (Documents, Library, tmp).
    - **App Group** — shared storage, e.g. a SwiftData database.
    - **On My iPhone** — the local “On My iPhone” files.

    The mounted location appears in the Finder sidebar under **Locations**.

    ## Working with files

    You can read, open, edit, rename, move, add and delete files directly in the Finder — changes are written straight into the Simulator.

    Files that the **running app** creates or changes appear automatically, as long as SimBridge stays open.

    ## Menu bar

    SimBridge lives in the menu bar. You can close the main window; the app keeps running so live updates continue. Open the main window again from the menu-bar item.

    ## Troubleshooting

    - **No simulators or apps shown** — start an app in the Simulator, then click **Refresh**. Use **Only running** to hide stopped simulators.
    - **Live updates don’t appear** — keep SimBridge open; the running app writes into the mounted folder.
    - **A folder looks empty** — the files you see in the iOS Files app may belong to a different app or the local “On My iPhone” storage, not the app you mounted.
    """

    private static let german = """
    # SimBridge

    SimBridge blendet den Dateispeicher deiner iOS-Simulator-Apps als Orte im macOS-Finder ein — so kannst du Dateien wie in jedem anderen Ordner durchsuchen, öffnen, bearbeiten, hinzufügen und löschen.

    ## Erste Schritte

    Erlaube SimBridge beim ersten Mal den Zugriff auf deinen Simulator-Ordner:

    - Klicke auf **Simulator-Zugriff erlauben…** (oder den Ordner-Button in der Symbolleiste).
    - Wähle im Dialog den Ordner **„Devices“** in **CoreSimulator** und klicke auf **Zugriff erlauben**.

    SimBridge merkt sich das — du machst es also nur einmal.

    ## Eine Quelle mounten

    Wähle links einen Simulator und klicke bei einer Quelle auf **Mounten**:

    - **App-Daten** — der Container der App (Documents, Library, tmp).
    - **App-Gruppe** — geteilter Speicher, z. B. eine SwiftData-Datenbank.
    - **Auf meinem iPhone** — die lokalen „Auf meinem iPhone“-Dateien.

    Der gemountete Ort erscheint im Finder unter **Speicherorte**.

    ## Mit Dateien arbeiten

    Du kannst Dateien direkt im Finder lesen, öffnen, bearbeiten, umbenennen, verschieben, hinzufügen und löschen — die Änderungen landen direkt im Simulator.

    Dateien, die die **laufende App** anlegt oder ändert, erscheinen automatisch, solange SimBridge geöffnet bleibt.

    ## Menüleiste

    SimBridge lebt in der Menüleiste. Du kannst das Hauptfenster schließen; die App läuft weiter, damit Live-Updates funktionieren. Öffne das Hauptfenster jederzeit wieder über das Menüleisten-Symbol.

    ## Problembehebung

    - **Keine Simulatoren oder Apps** — starte eine App im Simulator und klicke auf **Aktualisieren**. Mit **Nur laufende** blendest du gestoppte Simulatoren aus.
    - **Live-Updates erscheinen nicht** — lass SimBridge geöffnet; die laufende App schreibt in den gemounteten Ordner.
    - **Ein Ordner wirkt leer** — die in der iOS-Files-App sichtbaren Dateien gehören evtl. einer anderen App oder dem lokalen „Auf meinem iPhone“-Speicher, nicht der gemounteten App.
    """

    private static let spanish = """
    # SimBridge

    SimBridge muestra el almacenamiento de archivos de tus apps del Simulador de iOS como ubicaciones en el Finder de macOS, para que puedas explorar, abrir, editar, añadir y eliminar archivos como en cualquier otra carpeta.

    ## Primeros pasos

    La primera vez, concede a SimBridge acceso a tu carpeta del Simulador:

    - Haz clic en **Permitir acceso al simulador…** (o en el botón de carpeta de la barra de herramientas).
    - En el diálogo, selecciona la carpeta **«Devices»** dentro de **CoreSimulator** y haz clic en **Conceder acceso**.

    SimBridge lo recuerda, así que solo lo haces una vez.

    ## Montar una fuente

    Elige un simulador en la barra lateral y haz clic en **Montar** junto a una fuente:

    - **Datos de la app** — el contenedor de la app (Documents, Library, tmp).
    - **Grupo de apps** — almacenamiento compartido, p. ej. una base de datos SwiftData.
    - **En mi iPhone** — los archivos locales de «En mi iPhone».

    La ubicación montada aparece en el Finder, en **Ubicaciones**.

    ## Trabajar con archivos

    Puedes leer, abrir, editar, renombrar, mover, añadir y eliminar archivos directamente en el Finder; los cambios se escriben directamente en el Simulador.

    Los archivos que crea o cambia la **app en ejecución** aparecen automáticamente, mientras SimBridge siga abierto.

    ## Barra de menús

    SimBridge vive en la barra de menús. Puedes cerrar la ventana principal; la app sigue en ejecución para que continúen las actualizaciones en vivo. Abre de nuevo la ventana principal desde el icono de la barra de menús.

    ## Solución de problemas

    - **No se muestran simuladores ni apps** — inicia una app en el Simulador y haz clic en **Actualizar**. Usa **Solo en ejecución** para ocultar los simuladores detenidos.
    - **Las actualizaciones en vivo no aparecen** — mantén SimBridge abierto; la app en ejecución escribe en la carpeta montada.
    - **Una carpeta parece vacía** — los archivos que ves en la app Archivos de iOS pueden pertenecer a otra app o al almacenamiento local «En mi iPhone», no a la app que montaste.
    """
}
