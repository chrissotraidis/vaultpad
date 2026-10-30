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

        func scenario(_ name: String, _ test: (URL, URL) throws -> Void) throws {
            let source = root.appendingPathComponent(name).appendingPathComponent("source")
            let docs = root.appendingPathComponent(name).appendingPathComponent("documents")
            try fm.createDirectory(at: source, withIntermediateDirectories: true)
            try fm.createDirectory(at: docs, withIntermediateDirectories: true)
            try test(source, docs)
            try require(!(try fm.contentsOfDirectory(atPath: docs.path)).contains { $0.hasPrefix(".vaultpad-import-") }, "staging leaked")
            passed += 1
            print("PASS \(name)")
        }
        func manifest(_ source: URL, _ entries: [(String, Int64)]) -> ImportManifest {
            ImportManifest(root: source, items: entries.map {
                ImportItem(source: source.appendingPathComponent($0.0), relativeComponents: [$0.0], size: $0.1)
            }, totalBytes: entries.reduce(0) { $0 + $1.1 })
        }
        func reject(_ action: () throws -> Void) throws {
            var failed = false
            do { try action() } catch { failed = true }
            try require(failed, "invalid import reported success")
        }

        try scenario("missing-source-preserves-existing") { source, docs in
            let existing = docs.appendingPathComponent("master.dat")
            try Data("keep".utf8).write(to: existing)
            try reject { try VaultDataImporter.copy(manifest(source, [("master.dat", 99)]), to: docs) { _ in } }
            try require(try Data(contentsOf: existing) == Data("keep".utf8), "missing source destroyed existing data")
        }
        try scenario("later-input-failure-preserves-all") { source, docs in
            try Data("new".utf8).write(to: source.appendingPathComponent("master.dat"))
            for name in ["master.dat", "critter.dat"] { try Data("old".utf8).write(to: docs.appendingPathComponent(name)) }
            try reject { try VaultDataImporter.copy(manifest(source, [("master.dat", 3), ("critter.dat", 3)]), to: docs) { _ in } }
            for name in ["master.dat", "critter.dat"] {
                try require(try Data(contentsOf: docs.appendingPathComponent(name)) == Data("old".utf8), "partial import changed installed data")
            }
        }
        for expected: Int64 in [2, 9] {
            try scenario("changed-size-\(expected)") { source, docs in
                try Data("data".utf8).write(to: source.appendingPathComponent("master.dat"))
                try Data("old".utf8).write(to: docs.appendingPathComponent("master.dat"))
                try reject { try VaultDataImporter.copy(manifest(source, [("master.dat", expected)]), to: docs) { _ in } }
                try require(try Data(contentsOf: docs.appendingPathComponent("master.dat")) == Data("old".utf8), "changed source overwrote installed data")
            }
        }
        try scenario("same-source-destination") { _, docs in
            let data = Data(repeating: 120, count: 2_000_001)
            try data.write(to: docs.appendingPathComponent("master.dat"))
            var copied: Int64 = 0
            try VaultDataImporter.copy(manifest(docs, [("master.dat", Int64(data.count))]), to: docs) { copied = $0 }
            try require(try Data(contentsOf: docs.appendingPathComponent("master.dat")) == data, "self import destroyed source")
            try require(copied == data.count, "incorrect progress")
        }
        try scenario("successful-replacement-preserves-saves") { source, docs in
            try Data("new".utf8).write(to: source.appendingPathComponent("master.dat"))
            try Data("old".utf8).write(to: docs.appendingPathComponent("master.dat"))
            let save = docs.appendingPathComponent("data/savegame/slot1/save.dat")
            try fm.createDirectory(at: save.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("my save".utf8).write(to: save)
            try VaultDataImporter.copy(manifest(source, [("master.dat", 3)]), to: docs) { _ in }
            try require(try Data(contentsOf: docs.appendingPathComponent("master.dat")) == Data("new".utf8), "replacement failed")
            try require(try Data(contentsOf: save) == Data("my save".utf8), "save changed")
        }
        try scenario("failed-publish-preserves-destination") { source, docs in
            try Data("new".utf8).write(to: source.appendingPathComponent("master.dat"))
            let target = docs.appendingPathComponent("master.dat")
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            try Data("keep".utf8).write(to: target.appendingPathComponent("sentinel"))
            try reject { try VaultDataImporter.copy(manifest(source, [("master.dat", 3)]), to: docs) { _ in } }
            try require(try Data(contentsOf: target.appendingPathComponent("sentinel")) == Data("keep".utf8), "failed rename removed destination")
        }
        try scenario("empty-files-are-not-ready") { _, docs in
            for name in ["master.dat", "critter.dat"] { try Data().write(to: docs.appendingPathComponent(name)) }
            try require(!VaultDataImporter.isReady(in: docs), "empty data bypassed setup")
        }
        try scenario("manifest-validates-and-excludes-saves") { source, _ in
            // Sparse synthetic files satisfy only this importer's documented header/size checks.
            for (name, size): (String, UInt64) in [("MASTER.DAT", 100_000_000), ("CRITTER.DAT", 50_000_000)] {
                let file = source.appendingPathComponent(name)
                try Data([0x78, 0x9c]).write(to: file)
                let handle = try FileHandle(forWritingTo: file)
                try handle.truncate(atOffset: size)
                try handle.close()
            }
            let saves = source.appendingPathComponent("data/SAVEGAME/slot1")
            try fm.createDirectory(at: saves, withIntermediateDirectories: true)
            try Data("save".utf8).write(to: saves.appendingPathComponent("save.dat"))
            let result = try VaultDataImporter.manifest(for: source)
            try require(result.items.count == 2, "source saves entered import manifest")
            try require(VaultDataImporter.isReady(in: source), "valid data was not ready")
        }
        print("\(passed) import regressions passed")
    }
}
