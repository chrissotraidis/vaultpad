#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-0.1.0}"
configuration="${2:-Release}"
app_path="$repo_root/out/build/engine-ios-device/$configuration-iphoneos/fallout2-ce.app"
release_dir="$repo_root/out/release"
ipa="$release_dir/VaultPad-$version-unsigned.ipa"
checksum="$ipa.sha256"

"$repo_root/scripts/build-device.sh" "$configuration"
"$repo_root/scripts/verify-repository.sh" "$app_path"

staging="$(mktemp -d "${TMPDIR:-/tmp}/vaultpad-release.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

mkdir -p "$staging/Payload"
ditto "$app_path" "$staging/Payload/VaultPad.app"
mkdir -p "$release_dir"
rm -f "$ipa" "$checksum"
(
    cd "$staging"
    COPYFILE_DISABLE=1 /usr/bin/zip -qry "$ipa" Payload
)

archive_entries="$(unzip -Z1 "$ipa")"
if printf '%s\n' "$archive_entries" | rg -q '(^|/)__MACOSX/|(^|/)\._'; then
    echo "error: macOS metadata found in release archive" >&2
    exit 1
fi
if printf '%s\n' "$archive_entries" | rg -qi '(^|/)(ref|SAVEGAME)(/|$)|(^|/)(master|critter|patch[0-9]{3})\.dat$|\.sav$'; then
    echo "error: proprietary game or save data found in release archive" >&2
    exit 1
fi

digest="$(shasum -a 256 "$ipa" | awk '{print $1}')"
printf '%s  %s\n' "$digest" "$(basename "$ipa")" > "$checksum"

test -s "$ipa"
test -s "$checksum"
echo "$ipa"
echo "$checksum"
