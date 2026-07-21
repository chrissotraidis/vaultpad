# iPadOS 26 Direct touch smoke test — 2026-07-19

## Setup

- iPad Pro 11-inch (M5) Simulator, iPadOS 26.5
- VaultPad Debug Simulator build from `main` at `4c469b0`
- Engine submodule at `c83584d8f333cbd12aff9ddf94177ed3b970d689`
- Comfort preset at 806×556
- User-owned data copied from the ignored `ref/Fallout 2` folder into the private Simulator container
- Direct mode saved as `touch_mode=touch`; quick toolbar enabled

No Fallout game data was added to Git or to the app bundle.

## Results

| Interaction | Result | Evidence |
| --- | --- | --- |
| Simulator build and launch | Pass | The arm64 Debug build completed, installed as `com.chrissotraidis.vaultpad`, and launched on iPadOS 26.5. |
| Bring Your Own Game screen | Pass | The native onboarding rendered in landscape and its live Simulator capture was added to the README. |
| Reference-data import | Pass | `master.dat`, `critter.dat`, `patch000.dat`, `data`, and the generated `ce.dat` were present in the private Documents container; VaultPad advanced into the real game runtime. |
| Main-menu touch | Pass | Touch selected **New Game** and then **Take** on the character selector. |
| Settings access | Pass | The in-game **Settings** toolbar control opened the native VaultPad Settings screen and **Done** returned to gameplay. |
| Mode selectors | Pass | Hybrid, Direct, and Trackpad each selected visibly. |
| Settings persistence | Pass | **Save Changes** persisted Direct as `touch_mode=touch`; the screen correctly explained that a restart was required. |
| Direct world movement | Pass | After restart, a world tap moved the player from the Temple stairs across the exterior to the right-side scrub. |
| Cursor action | Pass | **Cursor** changed the world mode and reported `Cursor mode: Interact.` in the message display. |
| Item action | Pass | **Item Action** selected and reported `Item action: Aimed attack.` |
| Skill action | Pass | **Skills** opened Skilldex; choosing First Aid closed the panel and reported `First Aid selected. Tap a character.` |
| Inactive combat actions | Pass | **End Turn** and **End Combat** were dim outside combat and each explained that it is available during combat. |

## Open checks

- Cursor-speed slider movement was not conclusively verified through desktop pointer automation; confirm it with a manual Simulator touch/drag.
- Hybrid and Trackpad world behavior still need clean, mode-specific gameplay passes after restart.
- Multi-finger cursor, scrolling, Back, highlight, and quicksave gestures need direct Simulator gestures or physical-device testing.
- Combat, inventory, dialogue, barter, save/load, lifecycle, and long-session regression remain covered only by the earlier iPadOS 18.5 playtests until repeated on iPadOS 26.5.
