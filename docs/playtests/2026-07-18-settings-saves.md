# In-game settings and save round trip — 2026-07-18

## Build under test

- Simulator: iPad Pro 11-inch (M4), iPadOS 18.5
- Launch: engine development autoload into verified `SLOT02`
- Runtime touch mode for entry-point test: Direct

## Checks

| Check | Result | Evidence |
|---|---|---|
| Product settings entry exists in gameplay | Pass | Quick toolbar displayed `SET` beside the eight skill shortcuts. |
| Direct touch cannot fall through toolbar | Pass after fix | First pass moved the player under `SET`; toolbar routing was made mode-independent, and the second pass opened native settings without changing player position. |
| Native settings fit iPad landscape | Pass | Controls, Display, and Saves cards plus legal copy and actions fit without scrolling or truncation. |
| Control mode persists | Pass | Selected Hybrid; config changed from `touch_mode=touch` to `touch_mode=hybrid`. |
| Display preset persists | Pass | Selected Native; config wrote `resolution_x=1210`, `resolution_y=834`, and `[vaultpad] display_preset=native`. |
| Settings access remains enabled | Pass | Save Changes wrote `quick_toolbar_visible=1`. |
| Save export is shareable | Pass | iPad share sheet presented `VaultPad-Saves-2026-07-18-1156.zip` with Save to Files. |
| Export ZIP is valid | Pass | macOS `unzip -t` reported no errors across both slots, nested proto files, and `slotdat.ini`. |
| Save import accepts exported layout | Pass | Selected a folder containing the unzipped `SAVEGAME`; settings reported two imported slots. |
| Imported data is exact | Pass | `SLOT02/SAVE.DAT` matched the export fixture at SHA-256 `4e3646c5d25a2211ea66ccaf75ad3cd54d24a44fa7554c3047a2e1032bc1ec64`. |
| Import leaves no staging artifacts | Pass | No `.SLOTxx.importing` or `.SLOTxx.backup` directory remained after success. |
| Game resumes after closing settings | Pass | Done returned to the same Temple entrance position with the toolbar still visible. |
| Load-screen DONE label is touchable | Pass after fix | Added an iPad-only 105×44 logical target over the complete control; tapping the visible label loaded `SLOT02` without a development shortcut. |
| Load-screen CANCEL label is touchable | Pass after fix | Added the matching 112×44 logical target; tapping the visible label returned to the main menu. |
| Native display preset launches | Pass | Relaunch applied 1210×834 and rendered the 4:3 game surface, HUD, toolbar, menus, and saves without clipping. |

## Coverage boundary

The round trip used Simulator-only saves derived from VaultPad's own background autosaves. The native importer deliberately accepts a folder rather than arbitrary third-party ZIPs; exported ZIPs can be expanded in Files and their `SAVEGAME` folder selected. Physical-device Files providers and large long-play saves remain device validation items.
