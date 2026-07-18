#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
engine_dir="$repo_root/engine"
platform="${1:-simulator}"

command -v cmake >/dev/null 2>&1 || {
    echo "error: CMake 3.25 or newer is required (brew install cmake)." >&2
    exit 1
}
xcode-select -p >/dev/null 2>&1 || {
    echo "error: Xcode command-line tools are unavailable." >&2
    exit 1
}

if ! git -C "$engine_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$repo_root" submodule update --init --recursive
fi

case "$platform" in
    simulator)
        build_dir="$repo_root/out/build/engine-ios-sim"
        sdk="iphonesimulator"
        ;;
    device)
        build_dir="$repo_root/out/build/engine-ios-device"
        sdk="iphoneos"
        ;;
    *)
        echo "usage: $0 [simulator|device]" >&2
        exit 2
        ;;
esac

cmake_args=(
    -S "$engine_dir"
    -B "$build_dir"
    -G Xcode
    -DCMAKE_SYSTEM_NAME=iOS
    -DCMAKE_OSX_SYSROOT="$sdk"
    -DCMAKE_OSX_ARCHITECTURES=arm64
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
    -DFALLOUT_IOS_PRODUCT_SOURCES="$repo_root/ios/Launcher/VaultPadBootstrap.swift"
    -DFALLOUT_IOS_PRODUCT_ASSET_CATALOG="$repo_root/ios/Assets.xcassets"
)

# Reuse an existing dependency checkout when available. Otherwise CMake fetches
# the engine's pinned versions from their official repositories.
dependency_root="$engine_dir/out/build/macos/_deps"
if [[ -d "$dependency_root/sdl2-src" ]]; then
    cmake_args+=("-DFETCHCONTENT_SOURCE_DIR_SDL2=$dependency_root/sdl2-src")
fi
if [[ -d "$dependency_root/zlib-src" ]]; then
    cmake_args+=("-DFETCHCONTENT_SOURCE_DIR_ZLIB=$dependency_root/zlib-src")
fi

cmake "${cmake_args[@]}"
echo "$build_dir/fallout2-ce.xcodeproj"
