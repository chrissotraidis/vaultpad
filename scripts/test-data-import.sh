#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/vaultpad-import-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$repo_root/ios/Launcher/VaultDataImporter.swift" \
    "$repo_root/tests/VaultDataImporterTests.swift" -o "$test_dir/import-tests"
"$test_dir/import-tests"
