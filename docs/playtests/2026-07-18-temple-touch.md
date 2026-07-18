# Temple touch playtest — 2026-07-18

## Setup

- iPad Pro 11-inch (M4) Simulator, iOS 18.5
- Comfort preset at 806×556
- Hybrid touch mode
- Imported user-owned data in the app sandbox; no game data is tracked
- Session restored from VaultPad's rotating lifecycle autosaves

## Results

| Interaction | Result | Evidence |
| --- | --- | --- |
| Expanded quick toolbar | Pass | `CUR`, `ACT`, `TRN`, `CMB`, and `SET` fit beside all eight skill buttons without overlapping the HUD. |
| Cursor-mode control | Pass | `CUR` cycled action, attack, and movement modes without a hidden multi-finger gesture. |
| Direct combat movement | Pass | Touch moved the character up the exterior stairs, crossed into the Temple, and navigated the foyer one AP-limited path at a time. |
| End turn | Pass | `TRN` ended the player turn and allowed the giant ants to act. |
| End combat | Pass | `CMB` correctly refused while another hostile remained and removed the legacy combat controls once the encounter ended. |
| Normal melee | Pass | Touch selected adjacent ants, showed hit chance, spent AP, produced hit/miss feedback, and killed both foyer ants. |
| Aimed melee | Pass | `ACT` exposed the aimed attack; touch opened the body-part picker, selected the abdomen, and resolved the attack. |
| Skill shortcut | Pass | `LCK` changed to the lockpick targeting cursor without moving the player. |
| Inventory open | Pass | The legacy `INV` HUD control opened the inventory by direct touch during and outside combat. |
| Tap equip/unequip | Pass | Tap an item, then tap a hand slot moved it; the reverse sequence returned it to the inventory list. No drag was required. |
| Inventory close target | Pass after fix | The visible `DONE` text was inert in the first pass; an iPad-only 112×44 transparent target now closes the inventory from the label. |
| Save continuity | Pass | Backgrounding during the session created a new rotating autosave; reinstalling the rebuilt app preserved and restored it. |

## Iterations made from the session

1. Added touch-safe `CUR` and `ACT` controls so movement, interaction, aimed attacks, and reload/action cycling are discoverable.
2. Added `TRN` and `CMB` buttons required by the PRD's touch backlog.
3. Added the two-finger cursor gesture to first-run help.
4. Enlarged the inventory `DONE` target to the complete visible control.

## Remaining acceptance work

- Exercise world-map and Klamath area-transition touch play; dialogue, barter, and numeric entry are covered in [the Klamath checkpoint](2026-07-18-klamath-barter.md).
- Run the release/device build, legal asset scan, and final clean-install matrix.
