import SwiftUI
import UniformTypeIdentifiers
import UIKit

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

        """
        try config.write(to: destination, atomically: true, encoding: .utf8)
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
}

private struct ImportView: View {
    @State private var showingImporter = false
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

                    Button(model.phase == .ready ? "Play" : "Select Game Folder") {
                        if model.phase == .ready { model.finish() } else { showingImporter = true }
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
public func falloutRunIOSProductBootstrap() {
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
