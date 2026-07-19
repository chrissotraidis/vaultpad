#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
engine_dir="$repo_root/engine"
resource="$engine_dir/out/build/macos/ce.dat"

if [[ -f "$resource" ]]; then
    echo "$resource"
    exit 0
fi

cmake --preset macos -S "$engine_dir"
cmake --build --preset macos-release --target ce-dat-resource

test -s "$resource"
echo "$resource"
