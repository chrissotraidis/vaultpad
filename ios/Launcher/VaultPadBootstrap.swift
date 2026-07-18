import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@_silgen_name("falloutPauseIOSAudio")
private func falloutPauseIOSAudio()

@_silgen_name("falloutResumeIOSAudio")
private func falloutResumeIOSAudio()

@MainActor
private final class VaultPadAudioSession {
    static let shared = VaultPadAudioSession()

    private var observers: [NSObjectProtocol] = []

    private init() {}

    func configure() {
        guard observers.isEmpty else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            // SDL still has a usable default path if iOS declines activation.
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

            if type == .began {
                falloutPauseIOSAudio()
                return
            }

            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard options.contains(.shouldResume) else { return }
            try? session.setActive(true)
            falloutResumeIOSAudio()
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { notification in
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
            falloutPauseIOSAudio()
            try? session.setActive(true)
            falloutResumeIOSAudio()
        })
    }
}

private enum ImportFailure: LocalizedError {
    case missing(String)
    case invalid(String)
    case space(required: Int64, available: Int64)

    var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "This folder is missing \(name). Choose the folder that contains your Fallout 2 data files."
        case .invalid(let name):
            return "\(name) does not look like a valid Fallout 2 data file."
        case .space(let required, let available):
            let formatter = ByteCountFormatter()
            return "VaultPad needs \(formatter.string(fromByteCount: required)) free, but only \(formatter.string(fromByteCount: available)) is available."
        }
    }
}

private struct ImportItem {
    let source: URL
    let relativeComponents: [String]
    let size: Int64
}

private struct ImportManifest {
    let root: URL
    let items: [ImportItem]
    let totalBytes: Int64
}

private enum VaultDataImporter {
    private static let requiredSizes: [String: ClosedRange<Int64>] = [
        "master.dat": 100_000_000...1_000_000_000,
        "critter.dat": 50_000_000...750_000_000,
    ]

    static func isReady(in documents: URL) -> Bool {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documents.path)) ?? []
        let lowered = Set(names.map { $0.lowercased() })
        return requiredSizes.keys.allSatisfy(lowered.contains)
    }

    static func manifest(for selectedFolder: URL) throws -> ImportManifest {
        let root = try locateDataRoot(from: selectedFolder)
        let manager = FileManager.default
        let topLevel = try manager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        var byName: [String: URL] = [:]
        for url in topLevel { byName[url.lastPathComponent.lowercased()] = url }

        for (name, range) in requiredSizes {
            guard let url = byName[name] else { throw ImportFailure.missing(name) }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            let size = Int64(values.fileSize ?? 0)
            guard values.isRegularFile == true, range.contains(size), try hasZlibHeader(url) else {
                throw ImportFailure.invalid(name)
            }
        }

        var items: [ImportItem] = []
        for url in topLevel where url.pathExtension.lowercased() == "dat" {
            let size = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            items.append(ImportItem(source: url, relativeComponents: [url.lastPathComponent.lowercased()], size: size))
        }

        if let dataDirectory = byName["data"] {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
            let enumerator = manager.enumerator(
                at: dataDirectory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            while let url = enumerator?.nextObject() as? URL {
                let values = try url.resourceValues(forKeys: Set(keys))
                if values.isDirectory == true, url.lastPathComponent.lowercased() == "savegame" {
                    enumerator?.skipDescendants()
                    continue
                }
                guard values.isRegularFile == true else { continue }
                let relativePath = String(url.path.dropFirst(dataDirectory.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let components = ["data"] + relativePath.split(separator: "/").map { String($0).lowercased() }
                items.append(ImportItem(source: url, relativeComponents: components, size: Int64(values.fileSize ?? 0)))
            }
        }

        let total = items.reduce(Int64(0)) { $0 + $1.size }
        return ImportManifest(root: root, items: items, totalBytes: total)
    }

    static func copy(_ manifest: ImportManifest, to documents: URL, progress: @escaping (Int64) -> Void) throws {
        let manager = FileManager.default
        let available = Int64((try? documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0)
        let required = manifest.totalBytes + manifest.totalBytes / 10
        if available > 0, available < required {
            throw ImportFailure.space(required: required, available: available)
        }

        var completed: Int64 = 0
        var created: [URL] = []
        do {
            for item in manifest.items {
                let destination = item.relativeComponents.reduce(documents) { $0.appendingPathComponent($1) }
                try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if manager.fileExists(atPath: destination.path) {
                    try manager.removeItem(at: destination)
                }
                _ = manager.createFile(atPath: destination.path, contents: nil)
                created.append(destination)

                let input = InputStream(url: item.source)!
                let output = OutputStream(url: destination, append: false)!
                input.open()
                output.open()
                defer {
                    input.close()
                    output.close()
                }

                var buffer = [UInt8](repeating: 0, count: 1_048_576)
                while input.hasBytesAvailable {
                    let count = input.read(&buffer, maxLength: buffer.count)
                    if count < 0 { throw input.streamError ?? ImportFailure.invalid(item.source.lastPathComponent) }
                    if count == 0 { break }
                    var offset = 0
                    while offset < count {
                        let written = buffer.withUnsafeBytes { bytes -> Int in
                            let pointer = bytes.bindMemory(to: UInt8.self).baseAddress!.advanced(by: offset)
                            return output.write(pointer, maxLength: count - offset)
                        }
                        if written <= 0 { throw output.streamError ?? ImportFailure.invalid(item.source.lastPathComponent) }
                        offset += written
                    }
                    completed += Int64(count)
                    progress(completed)
                }
            }
        } catch {
            for url in created.reversed() { try? manager.removeItem(at: url) }
            throw error
        }
    }

    static func writeDefaultConfiguration(to documents: URL, displaySize: CGSize) throws {
        let destination = documents.appendingPathComponent("fallout2.cfg")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        let landscapeWidth = max(displaySize.width, displaySize.height)
        let landscapeHeight = min(displaySize.width, displaySize.height)
        let width = max(640, (Int(landscapeWidth / 1.5) / 2) * 2)
        let height = max(480, (Int(landscapeHeight / 1.5) / 2) * 2)
        let config = """
        [screen]
        resolution_x=\(width)
        resolution_y=\(height)
        scale=1
        windowed=0

        [input]
        touch_mode=hybrid
        touch_sensitivity=1.0

        [ui]
        auto_quick_save=3
        quick_toolbar_visible=1

        """
        try config.write(to: destination, atomically: true, encoding: .utf8)
    }

    static func writeTouchMode(_ mode: String, to documents: URL) throws {
        let destination = documents.appendingPathComponent("fallout2.cfg")
        var lines = try String(contentsOf: destination, encoding: .utf8)
            .components(separatedBy: .newlines)
        var inInputSection = false
        var replaced = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                inInputSection = trimmed.caseInsensitiveCompare("[input]") == .orderedSame
            } else if inInputSection && trimmed.lowercased().hasPrefix("touch_mode=") {
                lines[index] = "touch_mode=\(mode)"
                replaced = true
                break
            }
        }

        if !replaced {
            lines.append(contentsOf: ["", "[input]", "touch_mode=\(mode)"])
        }
        try lines.joined(separator: "\n").write(to: destination, atomically: true, encoding: .utf8)
    }

    private static func locateDataRoot(from selected: URL) throws -> URL {
        if containsRequiredFiles(selected) { return selected }
        let children = try FileManager.default.contentsOfDirectory(at: selected, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        if let nested = children.first(where: { containsRequiredFiles($0) }) { return nested }
        throw ImportFailure.missing("master.dat and critter.dat")
    }

    private static func containsRequiredFiles(_ url: URL) -> Bool {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        let lowered = Set(names.map { $0.lowercased() })
        return requiredSizes.keys.allSatisfy(lowered.contains)
    }

    private static func hasZlibHeader(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 2) ?? Data()
        return bytes.count == 2 && bytes[bytes.startIndex] == 0x78
    }
}

@MainActor
private final class ImportViewModel: ObservableObject {
    enum Phase { case waiting, validating, copying, ready }

    @Published var phase: Phase = .waiting
    @Published var progress = 0.0
    @Published var message: String?

    let documents: URL
    let finish: () -> Void

    init(documents: URL, finish: @escaping () -> Void) {
        self.documents = documents
        self.finish = finish
    }

    func importFolder(_ url: URL) {
        phase = .validating
        progress = 0
        message = nil

        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let manifest = try await Task.detached { try VaultDataImporter.manifest(for: url) }.value
                phase = .copying
                try await Task.detached { [documents] in
                    try VaultDataImporter.copy(manifest, to: documents) { completed in
                        Task { @MainActor in
                            self.progress = manifest.totalBytes == 0 ? 1 : Double(completed) / Double(manifest.totalBytes)
                        }
                    }
                }.value
                try VaultDataImporter.writeDefaultConfiguration(to: documents, displaySize: UIScreen.main.bounds.size)
                phase = .ready
                progress = 1
                message = "Import complete. Your game data stays on this iPad."
            } catch {
                phase = .waiting
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func startPlaying(touchMode: String) {
        do {
            try VaultDataImporter.writeTouchMode(touchMode, to: documents)
            finish()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct TouchModeChoice: Identifiable {
    let id: String
    let name: String
    let summary: String
    let icon: String
}

private struct ControlsView: View {
    let finish: (String) -> Void

    @State private var selectedMode = "hybrid"

    private let modes = [
        TouchModeChoice(id: "hybrid", name: "Hybrid", summary: "Tap the world directly. Precise screens fall back to a trackpad.", icon: "hand.tap"),
        TouchModeChoice(id: "touch", name: "Direct", summary: "Every tap lands where your finger is. Fastest once familiar.", icon: "scope"),
        TouchModeChoice(id: "trackpad", name: "Trackpad", summary: "Drag anywhere to move the cursor, then tap to click.", icon: "rectangle.and.hand.point.up.left"),
    ]

    private let gestures = [
        ("hand.tap", "Tap", "Select, move, or use"),
        ("hand.point.up.left", "Press and hold", "Open the action menu"),
        ("hand.draw", "Two-finger drag", "Scroll lists and panels"),
        ("arrow.down", "Three-finger swipe", "Back or Escape"),
        ("highlighter", "Three-finger hold", "Highlight nearby objects"),
        ("square.and.arrow.down", "Four-finger hold", "Quick save"),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.08, blue: 0.07).ignoresSafeArea()
            HStack(alignment: .top, spacing: 46) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("TOUCH CONTROLS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    Text("Choose how VaultPad should feel.")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    ForEach(modes) { mode in
                        Button {
                            selectedMode = mode.id
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.name).font(.headline)
                                    Text(mode.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.62))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: selectedMode == mode.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                            }
                            .foregroundStyle(.white)
                            .padding(18)
                            .background(
                                selectedMode == mode.id ? Color(red: 0.35, green: 0.29, blue: 0.12) : .white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedMode == mode.id ? Color(red: 0.82, green: 0.72, blue: 0.38).opacity(0.7) : .white.opacity(0.08))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 540, alignment: .leading)

                VStack(alignment: .leading, spacing: 18) {
                    Text("GESTURES")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.48))

                    ForEach(Array(gestures.enumerated()), id: \.offset) { _, gesture in
                        HStack(spacing: 14) {
                            Image(systemName: gesture.0)
                                .frame(width: 28)
                                .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(gesture.1).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text(gesture.2).font(.caption).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }

                    Spacer(minLength: 18)
                    Button("Start Playing") { finish(selectedMode) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color(red: 0.65, green: 0.52, blue: 0.18))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(28)
                .frame(width: 340)
                .frame(minHeight: 510, alignment: .topLeading)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
            }
            .padding(52)
        }
    }
}

private struct ImportView: View {
    @State private var showingImporter = false
    @State private var showingControls = false
    @StateObject var model: ImportViewModel

    var body: some View {
        ZStack {
            Color(red: 0.075, green: 0.08, blue: 0.07).ignoresSafeArea()
            HStack(spacing: 54) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("VAULTPAD")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))
                    Text("Bring your own game.\nKeep it on your iPad.")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Select the folder from a legally purchased copy of Fallout 2. VaultPad copies only the data the engine needs. Nothing is downloaded or uploaded.")
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Unofficial and not affiliated with Bethesda, ZeniMax, or Microsoft.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: 470, alignment: .leading)

                VStack(spacing: 18) {
                    Image(systemName: model.phase == .ready ? "checkmark.seal.fill" : "folder.badge.plus")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.38))

                    if model.phase == .copying {
                        ProgressView(value: model.progress)
                            .tint(Color(red: 0.82, green: 0.72, blue: 0.38))
                        Text("Copying… \(Int(model.progress * 100))%")
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let message = model.message {
                        Text(message)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(model.phase == .ready ? .white.opacity(0.75) : Color(red: 1, green: 0.62, blue: 0.46))
                    }

                    Button(model.phase == .ready ? "Continue" : "Select Game Folder") {
                        if model.phase == .ready { showingControls = true } else { showingImporter = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.65, green: 0.52, blue: 0.18))
                    .disabled(model.phase == .validating || model.phase == .copying)
                }
                .padding(32)
                .frame(width: 340)
                .frame(minHeight: 310)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 24))
            }
            .padding(54)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.importFolder(url) }
        }
        .fullScreenCover(isPresented: $showingControls) {
            ControlsView { mode in model.startPlaying(touchMode: mode) }
        }
    }
}

@MainActor
private enum BootstrapPresenter {
    static var window: UIWindow?

    static func present(documents: URL, completion: @escaping () -> Void) {
        let finish = {
            window?.isHidden = true
            window = nil
            completion()
        }
        let model = ImportViewModel(documents: documents, finish: finish)
        let controller = UIHostingController(rootView: ImportView(model: model))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }
}

@_cdecl("falloutRunIOSProductBootstrap")
@MainActor
public func falloutRunIOSProductBootstrap() {
    VaultPadAudioSession.shared.configure()

    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    guard !VaultDataImporter.isReady(in: documents) else { return }

    var finished = false
    let semaphore = DispatchSemaphore(value: 0)
    Task { @MainActor in
        BootstrapPresenter.present(documents: documents) {
            finished = true
            semaphore.signal()
        }
    }

    if Thread.isMainThread {
        while !finished {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
    } else {
        semaphore.wait()
    }
}
