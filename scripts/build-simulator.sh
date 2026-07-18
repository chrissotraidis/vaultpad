#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
project="$repo_root/out/build/engine-ios-sim/fallout2-ce.xcodeproj"
configuration="${1:-Debug}"

"$repo_root/scripts/configure.sh" simulator

xcodebuild \
    -project "$project" \
    -target fallout2-ce \
    -configuration "$configuration" \
    -sdk iphonesimulator \
    -arch arm64 \
    -xcconfig "$repo_root/ios/Config/VaultPad.xcconfig" \
    CODE_SIGNING_ALLOWED=NO \
    INFOPLIST_FILE="$repo_root/ios/Config/Info.plist" \
    build

app_path="$repo_root/out/build/engine-ios-sim/$configuration-iphonesimulator/fallout2-ce.app"

# The active engine currently builds ce.dat only from a desktop configuration.
# Keep the simulator artifact complete while the upstreamable bundle hook is
# developed in the engine fork.
ce_dat="$repo_root/engine/out/build/macos/ce.dat"
if [[ -f "$ce_dat" && -d "$app_path" ]]; then
    cp "$ce_dat" "$app_path/ce.dat"
fi

test -d "$app_path"
echo "$app_path"
