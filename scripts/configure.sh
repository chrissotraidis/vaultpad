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
    -DFALLOUT_IOS_PRODUCT_SOURCES="$repo_root/ios/Launcher/VaultPadBootstrap.swift;$repo_root/ios/Launcher/VaultPadSettings.swift"
    -DFALLOUT_IOS_PRODUCT_ASSET_CATALOG="$repo_root/ios/Assets.xcassets"
)

# SDL 2.32.10 plus the Pad ports UIKit scene startup commit: apps built with the
# iOS 27 SDK must start through UIKit scenes or iOS 27 closes them at launch.
sdl_dir="$repo_root/out/deps/sdl2-scenes"
sdl_pin="c6756fcd3de8090a8f72ac1a0b6fb6e50f0021d1"
if [[ "$(git -C "$sdl_dir" rev-parse HEAD 2>/dev/null || true)" != "$sdl_pin" ]]; then
    rm -rf "$sdl_dir"
    git init -q "$sdl_dir"
    git -C "$sdl_dir" fetch -q --depth 1 https://github.com/chrissotraidis/SDL.git "$sdl_pin"
    git -C "$sdl_dir" checkout -q --detach FETCH_HEAD
fi
cmake_args+=("-DFETCHCONTENT_SOURCE_DIR_SDL2=$sdl_dir")

# Reuse an existing zlib checkout when available. Otherwise CMake fetches the
# engine's pinned version from its official repository.
dependency_root="$engine_dir/out/build/macos/_deps"
if [[ -d "$dependency_root/zlib-src" ]]; then
    cmake_args+=("-DFETCHCONTENT_SOURCE_DIR_ZLIB=$dependency_root/zlib-src")
fi

cmake "${cmake_args[@]}"
echo "$build_dir/fallout2-ce.xcodeproj"
