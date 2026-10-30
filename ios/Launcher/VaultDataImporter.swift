import Foundation
import Darwin

enum ImportFailure: LocalizedError {
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

struct ImportItem {
    let source: URL
    let relativeComponents: [String]
    let size: Int64
}

struct ImportManifest {
    let root: URL
    let items: [ImportItem]
    let totalBytes: Int64
}

enum VaultDataImporter {
    private static let requiredSizes: [String: ClosedRange<Int64>] = [
        "master.dat": 100_000_000...1_000_000_000,
        "critter.dat": 50_000_000...750_000_000,
    ]

    static func isReady(in documents: URL) -> Bool {
        guard let files = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else { return false }
        return requiredSizes.allSatisfy { name, range in
            guard let url = files.first(where: { $0.lastPathComponent.lowercased() == name }),
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  range.contains(Int64(values.fileSize ?? 0)) else { return false }
            return (try? hasZlibHeader(url)) == true
        }
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

        // Read every input completely before changing installed data. A provider
        // can fail after validation, and the selected folder can be Documents itself.
        let staging = documents.appendingPathComponent(".vaultpad-import-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }
        var completed: Int64 = 0
        for item in manifest.items {
            let destination = item.relativeComponents.reduce(staging) { $0.appendingPathComponent($1) }
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard manager.createFile(atPath: destination.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let input = try FileHandle(forReadingFrom: item.source)
            let output = try FileHandle(forWritingTo: destination)
            defer {
                try? input.close()
                try? output.close()
            }
            var copied: Int64 = 0
            while let data = try input.read(upToCount: 1_048_576), !data.isEmpty {
                copied += Int64(data.count)
                guard copied <= item.size else { throw ImportFailure.invalid(item.source.lastPathComponent) }
                try output.write(contentsOf: data)
                completed += Int64(data.count)
                progress(completed)
            }
            guard copied == item.size else { throw ImportFailure.invalid(item.source.lastPathComponent) }
            try output.synchronize()
        }
        // The source can change after manifest validation without changing size.
        // Apply the same required-file checks to the bytes we will actually keep.
        guard isReady(in: staging) else { throw ImportFailure.invalid("The copied game data") }
        for item in manifest.items {
            let source = item.relativeComponents.reduce(staging) { $0.appendingPathComponent($1) }
            let destination = item.relativeComponents.reduce(documents) { $0.appendingPathComponent($1) }
            try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Same-volume rename replaces one complete file atomically. On failure
            // the previous file remains; never delete it to make room for a copy.
            guard rename(source.path, destination.path) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
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

