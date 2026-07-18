import SwiftUI
import UniformTypeIdentifiers
import UIKit

@_silgen_name("falloutPauseIOSAudio")
private func falloutPauseIOSAudio()

@_silgen_name("falloutResumeIOSAudio")
private func falloutResumeIOSAudio()

private enum VaultPadConfig {
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
        displayPreset = VaultPadConfig.value(section: "vaultpad", key: "display_preset", at: config) ?? "comfort"
    }

    func save() {
        do {
            try VaultPadConfig.set(section: "input", key: "touch_mode", value: touchMode, at: configURL)
            try VaultPadConfig.set(section: "input", key: "touch_sensitivity", value: String(format: "%.2f", sensitivity), at: configURL)
            try VaultPadConfig.set(section: "ui", key: "quick_toolbar_visible", value: "1", at: configURL)
            try VaultPadConfig.set(section: "vaultpad", key: "display_preset", value: displayPreset, at: configURL)

            let size = UIScreen.main.bounds.size
            let landscapeWidth = max(size.width, size.height)
            let landscapeHeight = min(size.width, size.height)
            let divisor = displayPreset == "native" ? 1.0 : 1.5
            let width = max(640, (Int(landscapeWidth / divisor) / 2) * 2)
            let height = max(480, (Int(landscapeHeight / divisor) / 2) * 2)
            try VaultPadConfig.set(section: "screen", key: "resolution_x", value: String(width), at: configURL)
            try VaultPadConfig.set(section: "screen", key: "resolution_y", value: String(height), at: configURL)
            message = "Saved. Restart VaultPad to apply display and control changes."
        } catch {
            message = error.localizedDescription
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

private struct VaultPadSettingsView: View {
    @StateObject var model: VaultPadSettingsModel
    @State private var importingSaves = false
    @State private var showingLicenses = false
    let close: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.08, blue: 0.07).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VAULTPAD SETTINGS")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(3)
                            .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                        Text("Changes stay on this iPad.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button("Done") { close() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .padding(.bottom, 28)

                HStack(alignment: .top, spacing: 24) {
                    settingsCard("Controls", icon: "hand.tap") {
                        Picker("Touch mode", selection: $model.touchMode) {
                            Text("Hybrid").tag("hybrid")
                            Text("Direct").tag("touch")
                            Text("Trackpad").tag("trackpad")
                        }
                        .pickerStyle(.segmented)
                        Text("Cursor speed  \(model.sensitivity, specifier: "%.1f")×")
                            .font(.subheadline.weight(.semibold))
                        Slider(value: $model.sensitivity, in: 0.5...2.0, step: 0.1)
                            .tint(Color(red: 0.82, green: 0.72, blue: 0.38))
                    }

                    settingsCard("Display", icon: "ipad.landscape") {
                        Picker("Display preset", selection: $model.displayPreset) {
                            Text("Comfort").tag("comfort")
                            Text("Native").tag("native")
                        }
                        .pickerStyle(.segmented)
                        Text(model.displayPreset == "native" ? "Sharper with smaller game UI." : "Larger controls and text for touch.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.58))
                        Text("Restart required")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    }

                    settingsCard("Saves", icon: "externaldrive") {
                        Button("Export Saves…") { model.exportSaves() }
                            .buttonStyle(.bordered)
                        Button("Import Save Folder…") { importingSaves = true }
                            .buttonStyle(.bordered)
                        Text("Exports a standard ZIP. Import accepts a SAVEGAME folder and preserves existing slots if copying fails.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer(minLength: 24)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unofficial and not affiliated with Bethesda, ZeniMax, or Microsoft.")
                        Text("No game content is included or uploaded.")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    Button("Licenses & Notices") { showingLicenses = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    Spacer()
                    if let message = model.message {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.trailing)
                    }
                    Button("Save Changes") { model.save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color(red: 0.65, green: 0.52, blue: 0.18))
                }
            }
            .padding(44)
        }
        .fileImporter(isPresented: $importingSaves, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.importSaves(from: url) }
        }
        .sheet(isPresented: $showingLicenses) {
            VaultPadLegalNoticesView()
        }
    }

    private func settingsCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
            content()
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 245, alignment: .topLeading)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
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

    static func present(documents: URL) {
        guard window == nil else { return }
        let close = {
            window?.isHidden = true
            window = nil
            falloutResumeIOSAudio()
        }
        let model = VaultPadSettingsModel(documents: documents)
        let controller = UIHostingController(rootView: VaultPadSettingsView(model: model, close: close))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
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
