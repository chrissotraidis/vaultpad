#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
artifact="${1:-}"

cd "$repo_root"

tracked_private="$(git ls-files | rg '(^|/)(ref|SAVEGAME)(/|$)|(^|/)(master|critter|patch[0-9]{3})\.dat$|\.(sav|ipa)$' || true)"
if [[ -n "$tracked_private" ]]; then
    echo "error: prohibited game/release data is tracked:" >&2
    echo "$tracked_private" >&2
    exit 1
fi

test "$(git config -f .gitmodules --get submodule.engine.url)" = "https://github.com/fallout2-ce/fallout2-ce.git"
test -f LICENSE.md
test -f THIRD_PARTY_NOTICES.md
test -s ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png

plutil -lint ios/Config/Info.plist >/dev/null
for script in scripts/*.sh; do
    bash -n "$script"
done

if [[ -n "$artifact" ]]; then
    test -d "$artifact"
    test -x "$artifact/fallout2-ce"
    test -f "$artifact/ce.dat"
    test -f "$artifact/LICENSE.md"
    test -f "$artifact/THIRD_PARTY_NOTICES.md"
    test -n "$(nm -g "$artifact/fallout2-ce" | rg '_falloutPresentIOSProductSettings$')"
    test -n "$(strings "$artifact/fallout2-ce" | rg 'VAULTPAD SETTINGS')"
    test ! -e "$artifact/master.dat"
    test ! -e "$artifact/critter.dat"
    if find "$artifact" -type f \( -iname 'master.dat' -o -iname 'critter.dat' -o -iname 'patch000.dat' -o -iname 'SAVE.DAT' \) | rg -q .; then
        echo "error: proprietary game or save data found in app artifact" >&2
        exit 1
    fi
fi

echo "VaultPad repository and artifact checks passed."
