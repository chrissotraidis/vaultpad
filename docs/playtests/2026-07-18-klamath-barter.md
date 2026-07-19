# Klamath dialogue and barter playtest — 2026-07-18

## Setup

- iPad Pro 11-inch (M4) Simulator, iOS 18.5
- Comfort preset at 806×556
- Direct Touch mode with the quick toolbar enabled
- User-owned Fallout 2 data imported into the app sandbox; no game data is tracked
- Disposable classic Klamath save copied only into Simulator `SLOT10`
- Checkpoint ZIP SHA-256: `5291de3caa9de2260e6614170db6cd2ae02f256be0f8750b2a39245a061cea4c`

## Results

| Interaction | Result | Evidence |
| --- | --- | --- |
| Classic save compatibility | Pass | The engine loaded the external Klamath checkpoint and entered Klamath Downtown without conversion or repair. |
| Direct world touch | Pass | Touch moved the player to Aldo; **Cursor** selected the interaction cursor and a touch on Aldo opened dialogue. |
| Dialogue choices | Pass | Touch selected a full response row and advanced the conversation. |
| `BARTER` label target | Pass after fix | The visible word originally did nothing while the tiny red lamp worked. The full label now opens barter. |
| Tap-to-offer | Pass after fix | A single item touch moves it from either inventory into the matching offer table; no drag gesture is required. |
| Tap-to-return | Pass after fix | Touching an item already in an offer table returns it to the owning inventory. |
| Stack quantity picker | Pass | Touching a stack of two opened `MOVE ITEMS` with the value initialized to one. |
| Software keyboard | Pass | The iPadOS keyboard appeared automatically; typing `2` updated the engine counter from `00001` to `00002`. |
| Keyboard dismissal | Pass | Confirming or cancelling the quantity dialog dismissed the keyboard and restored the full barter view. |
| Quantity label targets | Pass after fix | The complete `DONE` and `CANCEL` words now act as touch targets instead of requiring their small lamps. |
| `OFFER` label target | Pass after fix | Touching the visible label submitted a player item; Aldo accepted it and displayed `OK, that's a good trade.` |
| `TALK` label target | Pass after fix | Touching the visible label returned from barter to the dialogue response screen. |
| Area exit | Pass | Direct touch walked from Aldo to Klamath Downtown's east exit and transitioned to the world map. |
| World-map travel | Pass | Touch selected Arroyo from Klamath; the party marker traversed the map and advanced the game clock. |
| Town-map entry | Pass | Touch opened Arroyo's town map, selected `Village`, and loaded the playable village map. |

## Iterations made from the session

1. Kept desktop drag and Ctrl-transfer behavior intact while adding iOS-only tap transfers between each barter inventory and its offer table.
2. Preserved the quantity picker for touch transfers of stacked items instead of making them unconditional move-all actions.
3. Enlarged `BARTER`, `OFFER`, `TALK`, quantity `DONE`, and quantity `CANCEL` to cover their complete visible controls.
4. Rebuilt, reinstalled, and repeated the real dialogue/barter flow after each target change.

## Remaining acceptance work

- Verify an unsigned device build and release configuration.
- Run the final legal/tree scan, clean-install acceptance matrix, and artifact checksum checks.

## Data handling

The checkpoint and all proprietary game assets stayed in ignored local/Simulator storage. This repository contains only the SHA-256 above and behavioral test notes.
