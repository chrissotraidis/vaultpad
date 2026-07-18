# Save export and clean-reinstall recovery

Date: 2026-07-18

Device: iPad Pro 11-inch (M4) Simulator, iOS 18.5

Build: final Release simulator build

## Result

The complete PRD recovery chain passed: **export saves → delete app → reinstall → import saves → load**.

1. Exported six live save slots from VaultPad Settings. The iPad share sheet produced a 1.3 MB standard ZIP named `VaultPad-Saves-2026-07-18-1459.zip`.
2. Chose **Save to Files** and stored the archive at the root of **On My iPad**, outside VaultPad's app container.
3. Expanded the ZIP into the same Files-provider location. The folder contained `SLOT01`–`SLOT05`, `SLOT10`, and `slotdat.ini`.
4. Uninstalled only `com.chrissotraidis.vaultpad`, then installed the final Release simulator app.
5. Restored the licensed game assets from the private test backup while explicitly excluding `data/SAVEGAME/`. Verified the new sandbox had no save directory before launch.
6. Started a fresh premade character to reach gameplay and opened Settings from the touch toolbar.
7. Used **Import Save Folder…** and the native Files picker to select the exported folder under **On My iPad**.
8. Verified all six slots appeared in the new sandbox with no `.importing` or `.backup` staging artifacts.
9. Terminated and relaunched VaultPad, selected imported `SLOT10`, and loaded into responsive Klamath Downtown gameplay.

The exported and imported `SLOT10/SAVE.DAT` files have the same SHA-256:

`5d145ba3244e1514f34c0e535379842c61b909f2f6f004745a2a6311631f12b4`

## Boundary

The proprietary game assets were never placed in the export and are not part of the repository or application bundle. Their separate restoration was necessary only to make the clean installation playable before opening the in-game save importer.
