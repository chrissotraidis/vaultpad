# iPad lifecycle and autosave playtest

Date: 2026-07-18

Device: iPad Pro 11-inch (M4) Simulator, iOS 18.5

Scenario: fresh imported game, premade character at the Temple of Trials entrance

## Implementation contract

- `SDL_APP_WILLENTERBACKGROUND` and `SDL_APP_TERMINATING` synchronously save the current config.
- When a map is loaded, rotating quicksave is enabled, and no unsafe modal/save/load mode is active, backgrounding also performs one synchronous quicksave.
- A second app-state callback during the same background period cannot create a duplicate save.
- Foregrounding clears the per-cycle guard, refreshes the window, and resumes audio.
- `SDL_QUIT` requests the engine's normal shutdown path after the same flush/save step instead of calling `exit()` directly.
- Native first-run configuration enables three rotating quicksave slots.

## Simulator proof

1. Verified no save files existed before the test.
2. Started a premade character and reached controllable Temple gameplay.
3. Pressed the Simulator Home control.
4. VaultPad returned to the iPad Home screen and created a complete `SLOT02` save set, including:
   - `SAVE.DAT` (62,374 bytes)
   - `ARTEMPLE.SAV` (12,504 bytes)
   - `AUTOMAP.SAV`
   - `sfallgv.sav`
   - required proto snapshots
5. Reopened VaultPad. It resumed at the exact gameplay state and displayed **Game Saved.**
6. Moved the character, backgrounded a second time, and verified a new complete `SLOT03/SAVE.DAT` with a later timestamp.
7. Resumed, changed the character position, and pressed F7. The latest background save loaded successfully and restored the earlier character position; the engine displayed **Quick load game successfully loaded.**

## Remaining lifecycle matrix

- Repeat 50 cycles across movies, fades, combat, dialogue, barter, inventory, and save/load screens.
- Verify the save-safe skip path in every modal screen.
- Test process suspension/termination timing, audio interruption/route changes, low-memory delivery, and force-kill restore on physical iPad hardware.
- Confirm no Metal present/watchdog issue under physical-device background timing.

