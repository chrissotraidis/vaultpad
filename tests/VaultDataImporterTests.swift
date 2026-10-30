import Foundation

@main
enum VaultDataImporterTests {
    static func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw NSError(domain: message, code: 1) }
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("vaultpad-import-test-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var passed = 0
        let requiredFiles: [(String, UInt64)] = [("master.dat", 100_000_000), ("critter.dat", 50_000_000)]
        let oldMarker: UInt8 = 0x4f
        let newMarker: UInt8 = 0x4e

        func scenario(_ name: String, _ test: (URL, URL) throws -> Void) throws {
            let scenarioRoot = root.appendingPathComponent(name)
            defer { try? fm.removeItem(at: scenarioRoot) }
            let source = scenarioRoot.appendingPathComponent("source")
            let docs = scenarioRoot.appendingPathComponent("documents")
            try fm.createDirectory(at: source, withIntermediateDirectories: true)
            try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            try test(source, docs)
            try require(!(try fm.contentsOfDirectory(atPath: docs.path)).contains { $0.hasPrefix(".vaultpad-import-") }, "staging leaked")
            passed += 1
            print("PASS \(name)")
        }

        // Sparse synthetic files satisfy the unchanged production header/size
        // checks. They contain no game data and avoid allocating 150 MB in memory.
        func makeReadyFiles(_ folder: URL, marker: UInt8, uppercase: Bool = false) throws {
            for (name, size) in requiredFiles {
                let file = folder.appendingPathComponent(uppercase ? name.uppercased() : name)
                try Data([0x78, 0x9c, marker]).write(to: file)
                let handle = try FileHandle(forWritingTo: file)
                try handle.truncate(atOffset: size)
                try handle.close()
            }
            try require(VaultDataImporter.isReady(in: folder), "fixture does not satisfy production readiness")
        }
        func requireReadyFiles(_ folder: URL, marker: UInt8) throws {
            try require(VaultDataImporter.isReady(in: folder), "installed data is no longer ready")
            for (name, size) in requiredFiles {
                let file = folder.appendingPathComponent(name)
                let values = try file.resourceValues(forKeys: [.fileSizeKey])
                try require(values.fileSize == Int(size), "installed file length changed")
                let handle = try FileHandle(forReadingFrom: file)
                let prefix = try handle.read(upToCount: 3)
                try handle.close()
                try require(prefix == Data([0x78, 0x9c, marker]), "installed file was unexpectedly replaced")
            }
        }
        func reject(_ action: () throws -> Void) throws {
            var failed = false
            do { try action() } catch { failed = true }
            try require(failed, "invalid import reported success")
        }

        try scenario("missing-source-preserves-existing") { source, docs in
            try makeReadyFiles(source, marker: newMarker)
            try makeReadyFiles(docs, marker: oldMarker)
            let manifest = try VaultDataImporter.manifest(for: source)
            try fm.removeItem(at: manifest.items[0].source)
            try reject { try VaultDataImporter.copy(manifest, to: docs) { _ in } }
            try requireReadyFiles(docs, marker: oldMarker)
        }
        try scenario("later-input-failure-preserves-all") { source, docs in
            try makeReadyFiles(source, marker: newMarker)
            try makeReadyFiles(docs, marker: oldMarker)
            let manifest = try VaultDataImporter.manifest(for: source)
            try require(manifest.items.count == 2, "unexpected required fixture manifest")
            try fm.removeItem(at: manifest.items[1].source)
            var copied: Int64 = 0
            try reject { try VaultDataImporter.copy(manifest, to: docs) { copied = $0 } }
            try require(copied == manifest.items[0].size, "later failure did not follow a complete staged input")
            try requireReadyFiles(docs, marker: oldMarker)
        }
        for changedSize: UInt64 in [99_999_999, 100_000_001] {
            try scenario("changed-size-\(changedSize)") { source, docs in
                try makeReadyFiles(source, marker: newMarker)
                try makeReadyFiles(docs, marker: oldMarker)
                let manifest = try VaultDataImporter.manifest(for: source)
                let handle = try FileHandle(forWritingTo: source.appendingPathComponent("master.dat"))
                try handle.truncate(atOffset: changedSize)
                try handle.close()
                try reject { try VaultDataImporter.copy(manifest, to: docs) { _ in } }
                try requireReadyFiles(docs, marker: oldMarker)
            }
        }
        try scenario("same-size-header-change-preserves-ready-data") { source, docs in
            try makeReadyFiles(source, marker: newMarker)
            try makeReadyFiles(docs, marker: oldMarker)
            let manifest = try VaultDataImporter.manifest(for: source)
            let handle = try FileHandle(forWritingTo: source.appendingPathComponent("master.dat"))
            try handle.write(contentsOf: Data([0x00, 0x00]))
            try handle.close()
            var copied: Int64 = 0
            try reject { try VaultDataImporter.copy(manifest, to: docs) { copied = $0 } }
            try require(copied == manifest.totalBytes, "header regression did not reach staged validation")
            try requireReadyFiles(docs, marker: oldMarker)
        }
        try scenario("same-source-destination") { _, docs in
            try makeReadyFiles(docs, marker: oldMarker)
            let manifest = try VaultDataImporter.manifest(for: docs)
            var copied: Int64 = 0
            try VaultDataImporter.copy(manifest, to: docs) { copied = $0 }
            try requireReadyFiles(docs, marker: oldMarker)
            try require(copied == manifest.totalBytes, "incorrect progress")
        }
        try scenario("successful-replacement-preserves-saves") { source, docs in
            try makeReadyFiles(source, marker: newMarker)
            try makeReadyFiles(docs, marker: oldMarker)
            let save = docs.appendingPathComponent("data/savegame/slot1/save.dat")
            try fm.createDirectory(at: save.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("my save".utf8).write(to: save)
            let manifest = try VaultDataImporter.manifest(for: source)
            try VaultDataImporter.copy(manifest, to: docs) { _ in }
            try requireReadyFiles(docs, marker: newMarker)
            try requireReadyFiles(source, marker: newMarker)
            try require(try Data(contentsOf: save) == Data("my save".utf8), "save changed")
        }
        try scenario("failed-publish-preserves-destination") { source, docs in
            try makeReadyFiles(source, marker: newMarker)
            let manifest = try VaultDataImporter.manifest(for: source)
            let target = docs.appendingPathComponent(manifest.items[0].relativeComponents[0])
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: target.appendingPathComponent("sentinel"))
            var copied: Int64 = 0
            try reject { try VaultDataImporter.copy(manifest, to: docs) { copied = $0 } }
            try require(copied == manifest.totalBytes, "replacement failure did not follow complete staging")
            try require(try Data(contentsOf: target.appendingPathComponent("sentinel")) == Data("keep".utf8), "failed rename removed destination")
            try requireReadyFiles(source, marker: newMarker)
        }
        try scenario("empty-files-are-not-ready") { _, docs in
            for (name, _) in requiredFiles { try Data().write(to: docs.appendingPathComponent(name)) }
            try require(!VaultDataImporter.isReady(in: docs), "empty data bypassed setup")
        }
        try scenario("manifest-validates-and-excludes-saves") { source, _ in
            try makeReadyFiles(source, marker: newMarker, uppercase: true)
            let saves = source.appendingPathComponent("data/SAVEGAME/slot1")
            try fm.createDirectory(at: saves, withIntermediateDirectories: true)
            try Data("save".utf8).write(to: saves.appendingPathComponent("save.dat"))
            let result = try VaultDataImporter.manifest(for: source)
            try require(result.items.count == 2, "source saves entered import manifest")
            try require(result.totalBytes == 150_000_000, "incorrect required data size")
        }
        print("\(passed) import regressions passed")
    }
}
