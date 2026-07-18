#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-08636791-2675-4675-8335-EF72EF954DCF}"
data_source="${2:-}"
bundle_id="com.chrissotraidis.vaultpad"
app_path="$repo_root/out/build/engine-ios-sim/Debug-iphonesimulator/fallout2-ce.app"

if [[ ! -d "$app_path" ]]; then
    "$repo_root/scripts/build-simulator.sh" Debug
fi

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$app_path"

if [[ -n "$data_source" ]]; then
    if [[ ! -f "$data_source/master.dat" || ! -f "$data_source/critter.dat" ]]; then
        echo "error: data source must contain master.dat and critter.dat" >&2
        exit 2
    fi

    documents="$(xcrun simctl get_app_container "$device" "$bundle_id" data)/Documents"
    mkdir -p "$documents"
    ditto "$data_source/master.dat" "$documents/master.dat"
    ditto "$data_source/critter.dat" "$documents/critter.dat"
    [[ ! -f "$data_source/patch000.dat" ]] || ditto "$data_source/patch000.dat" "$documents/patch000.dat"
    [[ ! -d "$data_source/data" ]] || ditto "$data_source/data" "$documents/data"
    [[ ! -f "$repo_root/engine/out/build/macos/ce.dat" ]] || ditto "$repo_root/engine/out/build/macos/ce.dat" "$documents/ce.dat"
fi

xcrun simctl launch --terminate-running-process "$device" "$bundle_id"
