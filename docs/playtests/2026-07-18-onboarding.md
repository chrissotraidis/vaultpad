# Native onboarding and importer playtest

Date: 2026-07-18

Device: iPad Pro 11-inch (M4) Simulator, iOS 18.5

Build: VaultPad native launcher integrated into the active `vaultpad` engine branch

## Fresh-install proof

1. Preserved the prior Simulator Documents sandbox in `/private/tmp`, then uninstalled only `com.chrissotraidis.vaultpad`.
2. Installed the newly built arm64 Simulator app.
3. First launch displayed the original neutral VaultPad SwiftUI importer before SDL initialized.
4. No engine missing-file alert, proprietary artwork, game data, or credentials appeared in the app bundle or repository.

## Recovery proof

- Selected the empty VaultPad Files folder.
- The importer rejected it without crashing and named the missing files: `master.dat` and `critter.dat`.
- **Select Game Folder** remained available, and the next selection succeeded.

## Valid import proof

- Selected a private Simulator-only copy of the user-supplied Fallout 2 folder through the native folder picker.
- Validation accepted plausible `master.dat` (333,177,805 bytes) and `critter.dat` (166,951,131 bytes), including the expected compressed-data header.
- The importer copied root DAT files plus the `data/` tree, lowercasing destination path components and excluding prior saves.
- Copy progress completed and the UI changed to an explicit **Play** state.
- The generated `fallout2.cfg` contained:

```ini
[screen]
resolution_x=806
resolution_y=556
scale=1
windowed=0

[input]
touch_mode=hybrid
touch_sensitivity=1.0
```

- **Play** started the engine, opening movies rendered, and the main menu was reached at the generated aspect-exact Comfort resolution.
- `ce.dat` was absent from user Documents. Reaching the game therefore verifies the iOS app-bundle fallback.

## Data hygiene

- The proprietary source remained under ignored `ref/` and private Simulator storage only.
- No game data is tracked, staged, bundled, or pushed.
- The temporary Simulator source was used solely to exercise the same document-picker flow a real Files/iCloud/external-drive folder uses.

## Remaining importer work

- Add automated manifest/import unit coverage with synthetic fixtures.
- Exercise low-space and interrupted-copy cleanup paths.
- Verify iCloud-evicted files and external-drive throughput on physical hardware.
- Add Settings repair/replace/remove and save export/import surfaces in the reliability milestone.
