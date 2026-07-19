# Release clean-install playtest — 2026-07-18

## Build under test

- VaultPad parent checkpoint: `88812e5`
- Local engine checkpoint: `366d2041`
- Configuration: Release, arm64 iPad Simulator
- Simulator: 11-inch iPad Pro (M4), iPadOS 18.5
- Bundle: `com.chrissotraidis.vaultpad`, version 0.1.0 (1)

## Matrix

| Check | Result | Evidence |
|---|---|---|
| Recoverable pre-uninstall backup | Pass | Stopped the app, copied the resolved private container to `/private/tmp`, verified both root DATs, 123 save files, and the SLOT10 `SAVE.DAT` hash. |
| True clean install | Pass | Uninstalled only VaultPad, installed the Release app, and confirmed the new Documents folder contained no files or root game DATs. |
| First-run routing | Pass | The first launch opened the native “Bring your own game. Keep it on your iPad.” importer. |
| No bundled game content | Pass | The clean sandbox contained no `master.dat`, `critter.dat`, save, or patch DAT. |
| Backup restore integrity | Pass | Restored only the private Documents backup; SLOT10 `SAVE.DAT` retained SHA-256 `5d145ba3244e1514f34c0e535379842c61b909f2f6f004745a2a6311631f12b4`. |
| Existing-data routing | Pass | Relaunch skipped onboarding and reached the game main menu. |
| Release save load | Pass | Opened Load Game and activated the selected Klamath checkpoint with one touch; gameplay resumed with “Game Loaded.” |
| Legal notices | Pass | Settings opened from the touch toolbar; “Licenses & Notices” displayed the bundled Sustainable Use License and third-party notice with readable dark-mode contrast. |

## Defect found and fixed

The first Release retest exposed a legacy hover-order problem: a direct tap moved the cursor onto the load confirmation button, but the button needed a second tap to activate. A process stack sample showed the app remained healthy inside the load dialog loop; it was not hung.

Direct-touch synthesis now gives the legacy button manager four distinct ticks: position, hover update, press, and release. Rebuilding and reinstalling proved the same load confirmation activates on the first tap. The fix is local engine commit `366d2041`.

## Boundary

This is Simulator proof. It does not claim physical-device, hardware pointer, signed-install, TestFlight, or App Store validation. Proprietary data and backups remain outside Git.
