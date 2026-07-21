import SwiftUI
import UniformTypeIdentifiers
import UIKit

@_silgen_name("falloutPauseIOSAudio")
private func falloutPauseIOSAudio()

@_silgen_name("falloutResumeIOSAudio")
private func falloutResumeIOSAudio()

@_silgen_name("falloutApplyIOSTouchSettings")
private func falloutApplyIOSTouchSettings(_ touchMode: UnsafePointer<CChar>, _ sensitivity: Double, _ toolbarEnabled: Int32)

@_silgen_name("falloutResetIOSTouchState")
private func falloutResetIOSTouchState()

enum VaultPadConfig {
    static func value(section: String, key: String, at url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var activeSection = ""
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                activeSection = String(trimmed.dropFirst().dropLast()).lowercased()
            } else if activeSection == section.lowercased(),
                      let separator = trimmed.firstIndex(of: "=") {
                let candidate = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
                if candidate.caseInsensitiveCompare(key) == .orderedSame {
                    return String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    static func set(section: String, key: String, value: String, at url: URL) throws {
        var lines = (try? String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)) ?? []
        let sectionHeader = "[\(section)]"
        var sectionStart: Int?
        var sectionEnd = lines.endIndex

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { continue }
            if let start = sectionStart {
                sectionEnd = index
                if index > start { break }
            }
            if trimmed.caseInsensitiveCompare(sectionHeader) == .orderedSame {
                sectionStart = index
            }
        }

        if let start = sectionStart {
            for index in lines.index(after: start)..<sectionEnd {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                guard let separator = trimmed.firstIndex(of: "=") else { continue }
                if trimmed[..<separator].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(key) == .orderedSame {
                    lines[index] = "\(key)=\(value)"
                    try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
                    return
                }
            }
            lines.insert("\(key)=\(value)", at: sectionEnd)
        } else {
            if lines.last?.isEmpty == false { lines.append("") }
            lines.append(contentsOf: [sectionHeader, "\(key)=\(value)"])
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}

private enum SaveArchive {
    private struct Entry {
        let name: Data
        let crc32: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private static let crcTable: [UInt32] = (0..<256).map { value in
        var result = UInt32(value)
        for _ in 0..<8 {
            result = (result & 1) == 1 ? 0xEDB88320 ^ (result >> 1) : result >> 1
        }
        return result
    }

    static func create(from saveDirectory: URL) throws -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: saveDirectory.path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "No saves exist yet."])
        }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = manager.enumerator(at: saveDirectory, includingPropertiesForKeys: keys) else {
            throw CocoaError(.fileReadUnknown)
        }
        var files: [URL] = []
        while let file = enumerator.nextObject() as? URL {
            if (try? file.resourceValues(forKeys: Set(keys)).isRegularFile) == true {
                files.append(file)
            }
        }
        files.sort { $0.path < $1.path }

        guard !files.isEmpty else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "No saves exist yet."])
        }

        var archive = Data()
        var entries: [Entry] = []
        for file in files {
            let fileData = try Data(contentsOf: file)
            guard fileData.count <= UInt32.max, archive.count <= UInt32.max else {
                throw CocoaError(.fileWriteOutOfSpace, userInfo: [NSLocalizedDescriptionKey: "The save archive is too large."])
            }
            let relative = String(file.path.dropFirst(saveDirectory.path.count + 1))
            let name = Data(relative.replacingOccurrences(of: "\\", with: "/").utf8)
            let size = UInt32(fileData.count)
            let checksum = crc32(fileData)
            let offset = UInt32(archive.count)

            archive.appendLittleEndian(UInt32(0x04034B50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(checksum)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(name)
            archive.append(fileData)
            entries.append(Entry(name: name, crc32: checksum, size: size, offset: offset))
        }

        let centralOffset = UInt32(archive.count)
        for entry in entries {
            archive.appendLittleEndian(UInt32(0x02014B50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(entry.crc32)
            archive.appendLittleEndian(entry.size)
            archive.appendLittleEndian(entry.size)
            archive.appendLittleEndian(UInt16(entry.name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt32(0))
            archive.appendLittleEndian(entry.offset)
            archive.append(entry.name)
        }

        let centralSize = UInt32(archive.count) - centralOffset
        archive.appendLittleEndian(UInt32(0x06054B50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(centralSize)
        archive.appendLittleEndian(centralOffset)
        archive.appendLittleEndian(UInt16(0))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let destination = manager.temporaryDirectory.appendingPathComponent("VaultPad-Saves-\(formatter.string(from: Date())).zip")
        try? manager.removeItem(at: destination)
        try archive.write(to: destination, options: .atomic)
        return destination
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ UInt32.max
    }
}

@MainActor
private final class VaultPadSettingsModel: ObservableObject {
    @Published var touchMode: String
    @Published var sensitivity: Double
    @Published var toolbarVisible: Bool
    @Published var displayPreset: String
    @Published var message: String?

    let documents: URL

    private var configURL: URL { documents.appendingPathComponent("fallout2.cfg") }
    private var saveDirectory: URL { documents.appendingPathComponent("data/SAVEGAME") }

    init(documents: URL) {
        self.documents = documents
        let config = documents.appendingPathComponent("fallout2.cfg")
        touchMode = VaultPadConfig.value(section: "input", key: "touch_mode", at: config) ?? "hybrid"
        sensitivity = Double(VaultPadConfig.value(section: "input", key: "touch_sensitivity", at: config) ?? "1") ?? 1
        toolbarVisible = VaultPadConfig.value(section: "ui", key: "quick_toolbar_visible", at: config) != "0"
        let savedDisplayPreset = VaultPadConfig.value(section: "vaultpad", key: "display_preset", at: config)
        displayPreset = savedDisplayPreset == "native" || savedDisplayPreset == "expanded" ? "expanded" : "classic"
    }

    @discardableResult
    func save() -> Bool {
        do {
            try VaultPadConfig.set(section: "input", key: "touch_mode", value: touchMode, at: configURL)
            try VaultPadConfig.set(section: "input", key: "touch_sensitivity", value: String(format: "%.2f", sensitivity), at: configURL)
            try VaultPadConfig.set(section: "ui", key: "quick_toolbar_visible", value: toolbarVisible ? "1" : "0", at: configURL)
            try VaultPadConfig.set(section: "vaultpad", key: "display_preset", value: displayPreset, at: configURL)

            let size = UIScreen.main.bounds.size
            let landscapeWidth = max(size.width, size.height)
            let landscapeHeight = min(size.width, size.height)
            let width: Int
            let height: Int
            if displayPreset == "expanded" {
                width = max(640, (Int(landscapeWidth / 1.5) / 2) * 2)
                height = max(480, (Int(landscapeHeight / 1.5) / 2) * 2)
            } else {
                // Fallout's interface is exactly 640 pixels wide. A 640x480
                // surface fills a 4:3 iPad without stretching or side gutters.
                width = 640
                height = 480
            }
            try VaultPadConfig.set(section: "screen", key: "resolution_x", value: String(width), at: configURL)
            try VaultPadConfig.set(section: "screen", key: "resolution_y", value: String(height), at: configURL)

            touchMode.withCString {
                falloutApplyIOSTouchSettings($0, sensitivity, toolbarVisible ? 1 : 0)
            }
            message = "Controls applied. Display scale changes after relaunch."
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func resetToDefaults() {
        touchMode = "hybrid"
        sensitivity = 1
        toolbarVisible = true
        displayPreset = "classic"
        save()
        if message?.hasPrefix("Controls applied.") == true {
            message = "Defaults applied. Relaunch only to update display scale."
        }
    }

    func exportSaves() {
        do {
            let archive = try SaveArchive.create(from: saveDirectory)
            SettingsPresenter.share(archive)
        } catch {
            message = error.localizedDescription
        }
    }

    func importSaves(from selected: URL) {
        let accessed = selected.startAccessingSecurityScopedResource()
        defer { if accessed { selected.stopAccessingSecurityScopedResource() } }

        do {
            let manager = FileManager.default
            var source = selected
            let selectedChildren = try manager.contentsOfDirectory(at: selected, includingPropertiesForKeys: [.isDirectoryKey])
            if let nested = selectedChildren.first(where: { $0.lastPathComponent.caseInsensitiveCompare("SAVEGAME") == .orderedSame }) {
                source = nested
            }

            let slots = try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { url in
                    let name = url.lastPathComponent.uppercased()
                    guard name.range(of: #"^SLOT[0-9]{2}$"#, options: .regularExpression) != nil else { return false }
                    let files = (try? manager.contentsOfDirectory(atPath: url.path)) ?? []
                    return files.contains { $0.caseInsensitiveCompare("SAVE.DAT") == .orderedSame }
                }
            guard !slots.isEmpty else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Choose a SAVEGAME folder containing SLOT folders with SAVE.DAT files."])
            }

            try manager.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
            var backups: [(destination: URL, backup: URL)] = []
            do {
                for slot in slots {
                    let name = slot.lastPathComponent.uppercased()
                    let destination = saveDirectory.appendingPathComponent(name)
                    let incoming = saveDirectory.appendingPathComponent(".\(name).importing")
                    let backup = saveDirectory.appendingPathComponent(".\(name).backup")
                    try? manager.removeItem(at: incoming)
                    try? manager.removeItem(at: backup)
                    try manager.copyItem(at: slot, to: incoming)
                    if manager.fileExists(atPath: destination.path) {
                        try manager.moveItem(at: destination, to: backup)
                        backups.append((destination, backup))
                    }
                    try manager.moveItem(at: incoming, to: destination)
                }
                for pair in backups { try? manager.removeItem(at: pair.backup) }
            } catch {
                for pair in backups.reversed() {
                    try? manager.removeItem(at: pair.destination)
                    try? manager.moveItem(at: pair.backup, to: pair.destination)
                }
                throw error
            }
            message = "Imported \(slots.count) save slot\(slots.count == 1 ? "" : "s"). Restart before loading them."
        } catch {
            message = error.localizedDescription
        }
    }
}

private enum VaultPadTheme {
    static let background = Color(red: 0.055, green: 0.06, blue: 0.048)
    static let panel = Color(red: 0.105, green: 0.105, blue: 0.082)
    static let panelRaised = Color(red: 0.145, green: 0.135, blue: 0.09)
    static let gold = Color(red: 0.82, green: 0.72, blue: 0.38)
    static let brass = Color(red: 0.52, green: 0.40, blue: 0.13)
    static let ink = Color(red: 0.085, green: 0.075, blue: 0.045)
    static let text = Color.white.opacity(0.86)
    static let muted = Color.white.opacity(0.62)
    static let hairline = Color(red: 0.60, green: 0.52, blue: 0.28).opacity(0.60)
    static let terminal = Color(red: 0.45, green: 0.78, blue: 0.36)
}

private struct VaultPadButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(primary ? VaultPadTheme.ink : VaultPadTheme.gold)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(
                primary ? VaultPadTheme.gold.opacity(configuration.isPressed ? 0.72 : 0.92) : VaultPadTheme.panelRaised.opacity(configuration.isPressed ? 0.95 : 0.62),
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(primary ? VaultPadTheme.gold : VaultPadTheme.hairline, lineWidth: 1)
            }
    }
}

private struct VaultPadChoiceStrip<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selection == option.value ? VaultPadTheme.ink : VaultPadTheme.text)
                        .background(selection == option.value ? VaultPadTheme.gold : VaultPadTheme.background.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(VaultPadTheme.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(VaultPadTheme.hairline, lineWidth: 1)
        }
    }
}

private struct VaultPadSettingsView: View {
    @StateObject var model: VaultPadSettingsModel
    @State private var importingSaves = false
    @State private var showingLicenses = false
    let close: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VaultPadTheme.background, Color(red: 0.075, green: 0.072, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VAULTPAD // FIELD TERMINAL")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(VaultPadTheme.gold)
                        Text("TOUCH  /  DISPLAY  /  SAVE BACKUP   •   Changes apply only when you choose Apply & Return.")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(VaultPadTheme.muted)
                    }
                    Spacer()
                    Button("CANCEL") { close() }
                        .buttonStyle(VaultPadButtonStyle())
                }
                .padding(.bottom, 18)

                Rectangle()
                    .fill(VaultPadTheme.hairline)
                    .frame(height: 1)
                    .padding(.bottom, 20)

                HStack(alignment: .top, spacing: 16) {
                    settingsCard("01", icon: "hand.tap.fill", title: "TOUCH CONTROLS") {
                        fieldLabel("CONTROL MODEL")
                        VaultPadChoiceStrip(options: [
                            ("HYBRID", "hybrid"),
                            ("DIRECT", "touch"),
                            ("TRACKPAD", "trackpad"),
                        ], selection: $model.touchMode)
                        Text(touchModeDescription)
                            .font(.caption)
                            .foregroundStyle(VaultPadTheme.muted)

                        fieldLabel("TRACKPAD SPEED  \(String(format: "%.1f", model.sensitivity))×")
                        HStack(spacing: 10) {
                            Button("−") { adjustSensitivity(by: -0.1) }
                                .buttonStyle(VaultPadButtonStyle())
                                .accessibilityLabel("Decrease trackpad speed")
                            Slider(value: $model.sensitivity, in: 0.5...2.0, step: 0.1)
                                .tint(VaultPadTheme.gold)
                            Button("+") { adjustSensitivity(by: 0.1) }
                                .buttonStyle(VaultPadButtonStyle())
                                .accessibilityLabel("Increase trackpad speed")
                        }
                        .disabled(model.touchMode != "trackpad")
                        .opacity(model.touchMode == "trackpad" ? 1 : 0.38)

                        fieldLabel("GAMEPLAY COMMAND BAR")
                        VaultPadChoiceStrip(options: [
                            ("FULL BAR", true),
                            ("SETTINGS ONLY", false),
                        ], selection: $model.toolbarVisible)
                        Text(commandBarDescription)
                            .font(.caption)
                            .foregroundStyle(VaultPadTheme.muted)

                        fieldLabel("TOUCH SHORTCUTS")
                        VStack(alignment: .leading, spacing: 5) {
                            controlHint("TWO-FINGER DRAG", "Pan the map only while both fingers are down.")
                            controlHint("DIRECT TAP", "The cursor lands under your finger before the click.")
                            controlHint("TRACKPAD", "One-finger drag moves the cursor; tap clicks it.")
                        }
                    }

                    settingsCard("02", icon: "rectangle.on.rectangle", title: "DISPLAY") {
                        fieldLabel("INTERFACE SCALE")
                        VaultPadChoiceStrip(options: [
                            ("FULL HUD", "classic"),
                            ("MORE MAP", "expanded"),
                        ], selection: $model.displayPreset)
                        Text(model.displayPreset == "expanded"
                            ? "Shows more of the map, but Fallout’s original bottom HUD is narrower and centered."
                            : "Fills a 4:3 iPad with Fallout’s original HUD. Aspect ratio is preserved.")
                            .font(.callout)
                            .foregroundStyle(VaultPadTheme.text)
                        statusLine("RESTART REQUIRED")
                        Text("Full HUD is the touch default. More Map is optional for players who prefer extra scene area over larger controls.")
                            .font(.caption)
                            .foregroundStyle(VaultPadTheme.muted)

                        fieldLabel("COMBAT READOUT")
                        VStack(alignment: .leading, spacing: 7) {
                            controlHint("ACTION POINTS", "The green lights in Fallout’s HUD. Attacks spend them; End turn refills them.")
                            controlHint("ACTION", "Tap the named attack to cycle normal and aimed versions.")
                            controlHint("NEXT ACTION", "The Next button previews the alternate attack or equipped item before you switch.")
                            controlHint("TARGET %", "Your chance to hit. Aimed attacks cost more and can still miss.")
                        }
                    }

                    settingsCard("03", icon: "externaldrive.fill", title: "SAVE BACKUP") {
                        fieldLabel("LOCAL SAVEGAME SLOTS")
                        Button("EXPORT SAVES…") { model.exportSaves() }
                            .buttonStyle(VaultPadButtonStyle())
                        Button("IMPORT SAVE FOLDER…") { importingSaves = true }
                            .buttonStyle(VaultPadButtonStyle())
                        Text("Export creates a ZIP containing only save slots. Import accepts a SAVEGAME folder and preserves existing slots if copying fails. Game data is never included.")
                            .font(.caption)
                            .foregroundStyle(VaultPadTheme.muted)
                    }
                }
                .frame(maxHeight: .infinity)

                Spacer(minLength: 20)

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unofficial and not affiliated with Bethesda, ZeniMax, or Microsoft.")
                        Text("No game content is included or uploaded.")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(VaultPadTheme.muted)
                    Button("LICENSES & NOTICES") { showingLicenses = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(VaultPadTheme.gold)
                    Spacer()
                    if let message = model.message {
                        Text(message)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(VaultPadTheme.text)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 310, alignment: .trailing)
                    }
                    Button("RESTORE DEFAULTS") { model.resetToDefaults() }
                        .buttonStyle(VaultPadButtonStyle())
                    Button("APPLY & RETURN") {
                        if model.save() { close() }
                    }
                        .buttonStyle(VaultPadButtonStyle(primary: true))
                }
                .padding(14)
                .background(VaultPadTheme.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 3))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(VaultPadTheme.hairline, lineWidth: 1)
                }
            }
            .padding(36)
        }
        .fileImporter(isPresented: $importingSaves, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.importSaves(from: url) }
        }
        .sheet(isPresented: $showingLicenses) {
            VaultPadLegalNoticesView()
        }
    }

    private var touchModeDescription: String {
        switch model.touchMode {
        case "touch":
            return "Direct — every one-finger tap lands at your finger. Fast for movement and large targets."
        case "trackpad":
            return "Trackpad — drag one finger to move the cursor, then lift and tap to click at that cursor."
        default:
            return "Hybrid · Recommended — direct taps plus momentary two-finger map panning. Trackpad behavior is used only when you select it."
        }
    }

    private var commandBarDescription: String {
        model.toolbarVisible
            ? "Shows Move, Use, Attack, the current action cost, the next available action, End turn during combat, and Settings."
            : "Hides gameplay commands. A compact Settings tab remains at the lower-right edge so this choice is always reversible."
    }

    private func controlHint(_ label: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(VaultPadTheme.terminal)
            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(VaultPadTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func adjustSensitivity(by amount: Double) {
        let stepped = ((model.sensitivity + amount) * 10.0).rounded() / 10.0
        model.sensitivity = min(2.0, max(0.5, stepped))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(VaultPadTheme.muted)
    }

    private func statusLine(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(VaultPadTheme.gold)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
        }
        .foregroundStyle(VaultPadTheme.gold)
    }

    private func settingsCard<Content: View>(_ index: String, icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(index)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(VaultPadTheme.ink)
                    .frame(width: 28, height: 24)
                    .background(VaultPadTheme.gold)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VaultPadTheme.terminal)
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(VaultPadTheme.gold)
            }
            content()
        }
        .foregroundStyle(VaultPadTheme.text)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(VaultPadTheme.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 2))
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(VaultPadTheme.hairline, lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 1)
                .stroke(Color.black.opacity(0.65), lineWidth: 1)
                .padding(4)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VaultPadTheme.brass)
                .frame(height: 3)
                .padding(.horizontal, 1)
        }
    }
}

private struct VaultPadLegalNoticesView: View {
    @Environment(\.dismiss) private var dismiss

    private var notices: String {
        ["LICENSE.md", "THIRD_PARTY_NOTICES.md"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: nil) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n---\n\n")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                Text(notices.isEmpty ? "License files are unavailable in this build." : notices)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
            .background(Color(red: 0.075, green: 0.08, blue: 0.07))
            .foregroundStyle(.white.opacity(0.82))
            .navigationTitle("Licenses & Notices")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

@MainActor
private enum SettingsPresenter {
    static var window: UIWindow?
    static var previousKeyWindow: UIWindow?

    static func present(documents: URL) {
        guard window == nil else { return }
        let close = {
            let gameWindow = previousKeyWindow
            window?.isHidden = true
            window = nil
            gameWindow?.makeKeyAndVisible()
            previousKeyWindow = nil
            falloutResetIOSTouchState()
            falloutResumeIOSAudio()
        }
        let model = VaultPadSettingsModel(documents: documents)
        let controller = UIHostingController(rootView: VaultPadSettingsView(model: model, close: close))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
            window = UIWindow(windowScene: scene)
        } else {
            previousKeyWindow = UIApplication.shared.windows.first(where: \.isKeyWindow)
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window?.windowLevel = .alert + 1
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }

    static func share(_ url: URL) {
        guard let controller = window?.rootViewController else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = controller.view
        activity.popoverPresentationController?.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.maxY - 40, width: 1, height: 1)
        controller.present(activity, animated: true)
    }
}

@_cdecl("falloutPresentIOSProductSettings")
@MainActor
public func falloutPresentIOSProductSettings() {
    falloutPauseIOSAudio()
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    SettingsPresenter.present(documents: documents)
}
