# VaultPad testing and acceptance

This page records the current public testing boundary and the regression checks that matter for future changes. It replaces the earlier per-iteration audit and playtest archive.

## Proven project paths

| Area | Current evidence |
| --- | --- |
| Repository safety | The verifier rejects tracked game data, saves, signed IPAs, AppleDouble metadata, and accidental proprietary content. |
| Simulator builds | Debug and Release arm64 builds have run on 11-inch and 13-inch iPad Pro Simulator profiles. |
| Physical device | Signed development builds have been installed, updated in place, launched, and played on a 12.9-inch iPad Pro (6th generation). |
| First launch | Missing data produces native onboarding; a valid folder import reaches Fallout 2 without hand-editing configuration files. |
| Touch gameplay | Movement, interaction, map panning, combat, inventory, character creation, dialogue, barter, save/load, world-map travel, and settings return have been exercised through the game UI. |
| Saves | Save export, clean reinstall, game-data reimport, save-folder import, and load recovery have been exercised. |
| Lifecycle | Background quicksave, foreground return, audio-session recovery, and in-place app updates have been exercised. |

These results support a developer preview. They do not certify every iPad, peripheral, game mod, or long-session condition.

## Touch regression checklist

After changing touch, mouse, modal-window, display, or dock code, verify:

1. A direct tap places the game cursor under the finger before activating the target.
2. Returning from Preferences, Help, save/load, character creation, or VaultPad settings does not leave a stale or duplicated cursor.
3. A two-finger drag pans without issuing Use clicks, hover descriptions, movement, or attacks.
4. Lifting both fingers stops panning and restores the previously selected action.
5. Walk and Run toggle by tapping the selected movement button again.
6. Use and Attack arm the next world tap and remain visually distinct.
7. The current action shows its name plus Normal or Aimed and its action-point cost without clipping.
8. The alternate action switches hands or attacks and immediately arms targeting.
9. End Turn appears during combat, fits within its button, and advances the turn.
10. The VaultPad dock clears Fallout's original HUD and status plaques such as ADDICT or SNEAK.
11. The gear-and-VP badge opens the Field Terminal in both Full Dock and VP Only modes.
12. Apply & Return and Cancel restore finger-aligned gameplay input.

## Release checks

```bash
./scripts/verify-repository.sh
./scripts/build-simulator.sh Release
./scripts/package-release.sh 0.1.0 Release
```

A release candidate should also be installed over an existing physical-device build to confirm that imported data and saves remain intact.

## Not yet certified

- Hardware keyboard, Magic Keyboard trackpad, Bluetooth mouse, and Apple Pencil behavior
- Broad testing across every iPad size and supported iPadOS release
- Battery life, thermal behavior, and multi-hour sessions
- Exhaustive phone-call, Siri, route-change, and low-memory interruption handling
- TestFlight, App Store, or another supported public binary-distribution channel
- Restoration Project Updated or total-conversion compatibility
