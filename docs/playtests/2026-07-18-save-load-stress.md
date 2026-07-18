# Save/load stress playtest

Date: 2026-07-18

Device: iPad Pro 11-inch (M4) Simulator, iOS 18.5

Build: Release simulator build, restored from the verified clean-install backup

## Result

VaultPad completed **20 save/load cycles across three maps** without a save error, load error, crash, lost slot, or corrupted state.

| Map | Cycles | Result |
| --- | ---: | --- |
| Arroyo Temple Entrance | 6 | Every quicksave completed and every quickload restored controllable exterior gameplay. |
| Arroyo Temple Foyer | 7 | Every cycle restored the interior map; the final load also entered combat normally when a nearby ant took its turn. |
| Klamath Downtown | 7 | Every cycle restored the correct character, map, weapon/HUD state, and controllable gameplay. |

## Touch and lifecycle checks folded into the run

- Entered the Temple through its exterior doorway using direct touch and arrived on the interior map.
- Opened the load screen in active combat, navigated to the Klamath checkpoint, and loaded it successfully.
- Backgrounded and resumed three times during Temple combat; state returned intact.
- Backgrounded and resumed three times while the load dialog was open; the dialog returned intact.
- The final Klamath cycle ended with **Quick load game successfully loaded.** visible and gameplay responsive.

This satisfies the PRD's simulator-verifiable `20 save/load cycles across 3 maps` acceptance check. The separate export/reinstall/import/load chain also passed; see [2026-07-18-save-recovery.md](2026-07-18-save-recovery.md).
