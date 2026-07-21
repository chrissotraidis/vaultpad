# Touch command bar and Settings iteration — 2026-07-19

## Why this iteration happened

Direct iPadOS 26 testing found four problems in the prior six-button toolbar: it duplicated Fallout's Skilldex and combat controls, made cursor selection an opaque cycle, used unclear item-action wording, and could intercept a Skilldex Cancel tap before the modal received it. The native Settings screen also looked like generic SwiftUI rather than part of the same dark metal and amber control language.

## Test setup

- iPad Pro 11-inch (M5) Simulator, iPadOS 26.5
- VaultPad arm64 Debug Simulator build
- Existing user-owned Fallout 2 data preserved by installing over the current app
- Direct touch and Comfort display preset

No proprietary game data was added to the app bundle or Git.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Simulator build | Pass | Swift, C++, link, and bundle phases completed with `BUILD SUCCEEDED`. |
| In-place install and launch | Pass | `com.chrissotraidis.vaultpad` relaunched from the rebuilt app without repeating game-data import. |
| Command hierarchy | Pass | Duplicate Skills, End Turn, and End Combat controls were removed. Fallout's original HUD remains the single location for those actions. |
| Cursor choice | Pass | Move and Use are direct, persistent selections with a visible selected state. Attack is a separate combat-only choice in the implementation. |
| Item-action clarity | Pass | The live bar changed from `Attack: Normal` to `Attack: Aimed`; the message display reported `Weapon set to aimed attack. Tap Attack, then a target.` |
| Visual integration | Pass | The wide black slabs were replaced by one compact, beveled dark-metal panel using Fallout's muted amber/olive palette. |
| Skilldex Cancel | Pass | Cancel closed Skilldex and did not open VaultPad Settings. |
| Modal tap shielding | Pass | With Skilldex open, a tap directly over the Settings region left Skilldex open and did not activate Settings. |
| Settings visual system | Pass | Generic white segmented pills and rounded cards were replaced with square amber selectors, numbered metal panels, monospaced labels, a framed command footer, and explicit selected states. |
| Settings precision and semantics | Pass | Trackpad speed is visibly disabled outside Trackpad mode, has step buttons as well as a slider, and the command-bar preference is labeled `Actions` versus `Settings only`. |

## Remaining physical-device gate

This pass proves the implementation and Simulator interactions. Final acceptance still needs real-finger checks on the iPad for target comfort, rapid mode switching, combat Attack visibility, long-press and multi-finger gesture coexistence, and contrast under the actual display's brightness settings.
