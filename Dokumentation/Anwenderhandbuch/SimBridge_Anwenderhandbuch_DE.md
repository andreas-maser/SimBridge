---
lang: de
---

# Was SimBridge macht

SimBridge blendet die Datei-Ablage deiner **iOS-Simulator-Apps** als ganz normalen Ort im **macOS-Finder** ein. Statt dich durch kryptische Pfade wie `~/Library/Developer/CoreSimulator/Devices/<UUID>/…` zu wühlen, öffnest, bearbeitest, kopierst, benennst um und löschst du die Dateien direkt im Finder — und Änderungen erscheinen live, solange SimBridge läuft.

Dieses Handbuch führt dich in wenigen Minuten durch alles Wichtige: Zugriff einrichten, einen Ort mounten, im Finder arbeiten, aufräumen — plus die Grenzen und die häufigsten Stolpersteine.

# Voraussetzungen

- **macOS 14** (Sonoma) oder neuer.
- **Xcode** mit den Simulatoren, in die du schauen willst.
- SimBridge ist installiert und liegt in **`/Programme`** (von dort starten — nicht aus dem Download-Ordner).

# In einer Minute startklar

1. SimBridge öffnen.
2. Beim ersten Mal **Simulator-Zugriff erlauben** (einmalig, siehe nächster Abschnitt).
3. Links einen Simulator wählen, rechts bei einer Quelle auf **Mounten** tippen.
4. Der Ort erscheint im **Finder** unter *Speicherorte* — fertig.

Der Rest dieses Handbuchs erklärt jeden Schritt genauer.

# Schritt 1 — Simulator-Zugriff erteilen (einmalig)

Damit SimBridge deine Simulatoren findet, brauchst du einmal deine Erlaubnis für den CoreSimulator-Ordner. Das ist eine reine macOS-Sicherheitsabfrage; SimBridge merkt sich die Freigabe.

> **So geht's:**
> 1. Klicke auf **Simulator-Zugriff erlauben…** (oder oben in der Symbolleiste auf den Ordner-Knopf).
> 2. Im Dialog den Ordner **„Devices"** innerhalb von **CoreSimulator** einmal anklicken.
> 3. Auf **Zugriff erlauben** klicken.

Danach zeigt die Seitenleiste deine Simulatoren. Diesen Schritt machst du nur einmal.

Siehst du keine Simulatoren? Starte einen Simulator in Xcode, installiere/öffne dort deine App und klicke in SimBridge auf **Aktualisieren**.

# Schritt 2 — Einen Ort mounten

Wähle links einen Simulator. Rechts siehst du bis zu drei **Quell-Typen** — je nachdem, wo die Dateien liegen, die du suchst:

- **App-Daten** — der Container deiner App: `Documents`, `Library`, `tmp`. Hier landet das meiste, was deine App selbst speichert.
- **App-Gruppe** — geteilter Speicher der App, z. B. eine **SwiftData-Datenbank** (`default.store`) oder Dateien, die App und Extensions gemeinsam nutzen.
- **Auf meinem iPhone** — der lokale „Auf meinem iPhone"-Speicher, den die iOS-Dateien-App anzeigt.

> **So geht's:**
> 1. Simulator links auswählen.
> 2. Neben der gewünschten Quelle auf **Mounten** klicken.
> 3. Der Ort erscheint im Finder unter *Speicherorte* und in SimBridge unter **Gemountet**.

Ein Tipp, falls du eine Datei suchst und sie nicht findest: Was die iOS-Dateien-App unter „Auf meinem iPhone" zeigt, liegt oft **nicht** im `Documents` der App, sondern im lokalen Speicher oder in der App-Gruppe. Probier im Zweifel alle drei Quell-Typen.

# Schritt 3 — Im Finder arbeiten

Der gemountete Ort verhält sich wie jeder andere Ordner im Finder. Du kannst:

- Dateien und Ordner **öffnen und ansehen**,
- Inhalte **bearbeiten** (Änderungen landen direkt im Simulator),
- neue Dateien und Ordner **anlegen**,
- **umbenennen**, **verschieben** und **löschen**,
- Dateien per Drag & Drop **hinein- und herauskopieren**.

Damit kannst du z. B. schnell eine vorbereitete Testdatei in den App-Container legen, eine SwiftData-Datenbank zur Inspektion herauskopieren oder ein kaputtes Preferences-File löschen.

# Live-Aktualisierung

Dateien, die deine **laufende App** anlegt oder ändert, erscheinen automatisch im Finder — **solange SimBridge geöffnet ist**. Du musst nichts aktualisieren; der Ort hält sich von selbst auf dem neuesten Stand.

Tiefer verschachtelte Änderungen frischen sich auf, sobald du den betreffenden Ordner im Finder (erneut) öffnest.

# Aus der Menüleiste arbeiten

SimBridge lebt in der **Menüleiste**. Du kannst das Hauptfenster ruhig schließen — die App läuft weiter, damit die Live-Aktualisierung nicht abreißt. Über das Menüleisten-Symbol öffnest du das Hauptfenster jederzeit wieder und siehst auf einen Blick, was gerade gemountet ist.

# Nur laufende Simulatoren anzeigen

Wenn du viele Simulatoren angelegt hast, wird die Liste lang. Mit dem Schalter **Nur laufende** oben in der Symbolleiste blendest du alle gestoppten Simulatoren aus und siehst nur den, mit dem du gerade arbeitest.

# Orte entfernen & aufräumen

Einen einzelnen Ort nimmst du mit **Entfernen** wieder aus dem Finder (die Dateien im Simulator bleiben natürlich unangetastet — es wird nur der Finder-Ort abgemeldet).

Über das **„…"-Menü** oben rechts gibt es zwei Aufräum-Aktionen:

- **Nicht verfügbare Orte entfernen** — räumt Orte weg, deren Simulator oder App es nicht mehr gibt (z. B. weil du den Simulator gelöscht hast). Solche Orte sind in der Liste ausgegraut und mit einem Warnsymbol markiert.
- **Alle Finder-Orte entfernen…** — meldet in einem Rutsch alle SimBridge-Orte ab. Nützlich, falls einmal etwas hängt. Du kannst danach jederzeit neu mounten.

# Was SimBridge (noch) nicht tut — die Grenzen

- **Nur Simulatoren, keine echten Geräte.** Die Dateien eines physischen iPhones lassen sich technisch nicht auf demselben Weg einblenden. Für Geräte nutzt du weiterhin Xcode bzw. `xcrun devicectl` im Terminal.
- **Kein Mac-App-Store-Programm.** SimBridge greift auf Xcodes CoreSimulator-Ordner zu — das ist mit den App-Store-Regeln unvereinbar. Deshalb wird es außerhalb des Stores verteilt (signiert und notarisiert), damit macOS ihm vertraut.

# Wenn etwas klemmt

**Keine Simulatoren oder Apps sichtbar.** Starte einen Simulator in Xcode, installiere/öffne dort deine App, und klicke in SimBridge auf **Aktualisieren**. Prüfe außerdem, ob der Zugriff erteilt ist (Schritt 1).

**Der Ort erscheint, aber es lädt nichts.** Aktiviere den Ort im **Finder** — je nach macOS-Version musst du ihn in der Finder-Seitenleiste bzw. in den Finder-Einstellungen einmal einschalten. Danach zeigt er seinen Inhalt.

**Ein Ort ist ausgegraut („Nicht verfügbar").** Dann existiert der zugehörige Simulator oder die App nicht mehr. Über **„…" → Nicht verfügbare Orte entfernen** wirst du ihn los.

**Ein Ort hängt und lässt sich nicht entfernen.** Nutze **„…" → Alle Finder-Orte entfernen…** und mounte anschließend neu.

# Symbole auf einen Blick

- **Blitz** — Schalter *Nur laufende*: zeigt nur gestartete Simulatoren.
- **Ordner mit Zahnrad** — Simulator-Zugriff erteilen oder ändern.
- **Kreispfeil** — Aktualisieren: Simulatoren und Orte neu einlesen.
- **Blaue App-Kachel** — App-Daten (Documents/Library/tmp).
- **Lila Paket-Kachel** — App-Gruppe (z. B. SwiftData-Datenbank).
- **Türkise Laufwerk-Kachel** — Auf meinem iPhone (lokaler Speicher).
- **Grüner Punkt** — der Simulator läuft gerade.

Die gleiche Legende findest du jederzeit im Programm unter **Hilfe** (⌘?).

# Kurz & gut

Zugriff einmal erteilen, Quelle mounten, im Finder arbeiten — mehr ist es nicht. SimBridge macht aus dem lästigen Pfad-Wühlen einen Doppelklick in der Seitenleiste. Viel Spaß beim Entwickeln.
