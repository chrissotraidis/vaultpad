#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
engine_dir="$repo_root/engine"
resource="$engine_dir/out/build/macos/ce.dat"

if [[ -f "$resource" ]]; then
    echo "$resource"
    exit 0
fi

# Xcode 27 accepts macOS deployment targets from 12.0; the engine preset
# defaults to 10.13, which fails CMake's compiler checks. ce.dat is a host-side
# build resource, so this does not change the iOS app's supported systems.
cmake --preset macos -S "$engine_dir" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${VAULTPAD_HOST_MACOS_DEPLOYMENT_TARGET:-12.0}"
cmake --build "$engine_dir/out/build/macos" --config RelWithDebInfo --target ce-dat-resource

test -s "$resource"
echo "$resource"
