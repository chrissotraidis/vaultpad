#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
project="$repo_root/out/build/engine-ios-sim/fallout2-ce.xcodeproj"
configuration="${1:-Debug}"

"$repo_root/scripts/build-ce-dat.sh"
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

ce_dat="$repo_root/engine/out/build/macos/ce.dat"
cp "$ce_dat" "$app_path/ce.dat"
cp "$repo_root/LICENSE.md" "$app_path/LICENSE.md"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$app_path/THIRD_PARTY_NOTICES.md"

test -d "$app_path"
test -f "$app_path/ce.dat"
test -f "$app_path/LICENSE.md"
test -f "$app_path/THIRD_PARTY_NOTICES.md"
echo "$app_path"
