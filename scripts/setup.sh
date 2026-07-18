#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
signing="$repo_root/ios/Config/Signing.xcconfig"

command -v cmake >/dev/null 2>&1 || {
    echo "error: CMake 3.25 or newer is required (brew install cmake)." >&2
    exit 1
}

cmake_version="$(cmake --version | head -1 | awk '{print $3}')"
minimum_version="3.25.0"
if [[ "$(printf '%s\n' "$minimum_version" "$cmake_version" | sort -V | head -1)" != "$minimum_version" ]]; then
    echo "error: CMake $minimum_version or newer is required; found $cmake_version." >&2
    exit 1
fi

xcode-select -p >/dev/null 2>&1 || {
    echo "error: Xcode command-line tools are unavailable." >&2
    exit 1
}

if ! git -C "$repo_root/engine" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$repo_root" submodule update --init --recursive
fi

if [[ ! -f "$signing" ]]; then
    cp "$repo_root/ios/Config/Signing.template.xcconfig" "$signing"
    echo "Created ios/Config/Signing.xcconfig. Add your Apple development team before device builds."
fi

"$repo_root/scripts/configure.sh" simulator

echo
echo "VaultPad is ready."
echo "Build:   ./scripts/build-simulator.sh"
echo "Install: ./scripts/install-simulator.sh"
echo "Xcode:   out/build/engine-ios-sim/fallout2-ce.xcodeproj"
