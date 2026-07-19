# First-run touch controls — 2026-07-18

## Build under test

- Simulator: iPad Pro 11-inch (M4), iPadOS 18.5
- Bundle id: `com.chrissotraidis.vaultpad`
- Input modes: Hybrid, Direct, Trackpad

## Checks

| Check | Result | Evidence |
|---|---|---|
| Controls screen follows a real import | Pass | Temporarily removed the Simulator-only root DAT files, selected the existing private test-data folder, completed the import, and tapped Continue. |
| Default choice is understandable | Pass | Hybrid is selected and described as direct world taps with trackpad behavior on precision screens. |
| All engine modes are exposed | Pass | Hybrid, Direct, and Trackpad cards are individually selectable with distinct descriptions. |
| Required gestures are discoverable | Pass | Screen lists tap, long-press, two-finger drag, three-finger swipe/hold, and four-finger quicksave. |
| Layout fits iPad landscape | Pass | Rechecked after allowing two-line summaries; no card copy is truncated at 834×1194 logical portrait hardware bounds in landscape. |
| Selection persists | Pass | Direct wrote `touch_mode=touch`; a second full pass left the default Hybrid choice and wrote `touch_mode=hybrid`. |
| Engine starts from the controls screen | Pass | Start Playing dismissed the native layer and launched the intro movie both times. |

## Notes

The private game files used for this check stayed in Simulator containers and recoverable `/private/tmp` backups. No game content was added to Git.
