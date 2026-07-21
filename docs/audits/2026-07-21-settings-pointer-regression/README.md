# Settings and pointer regression check — 2026-07-21

## Scope

Checked the current iPad simulator build after the Field Terminal and touch-input changes. The simulator is an iPad Pro 13-inch (M5) running iOS 26.5.

## Checkpoints

1. **Field Terminal presentation — healthy.** The three sections remain readable at full-screen iPad scale, the Fallout-inspired brass/olive/terminal-green system is consistent, and the increased secondary-text and border contrast does not overpower the game UI.
2. **Direct pointer recovery — fixed by input-state logic.** The first direct touch now places the pointer immediately. A second active touch is excluded from pointer placement.
3. **Two-finger map pan isolation — fixed by input-state logic.** Gesture processing only recenters the pointer for a single active touch, so a two-finger pan cannot pull it to the gesture midpoint.
4. **Settings/modal return — fixed by input-state logic.** Returning to the game clears active touches, mouse deltas, pending clicks, and pan mode before restoring the game window.
5. **Build — passed.** The Debug iPad simulator target built successfully with Xcode 26.6 after the changes.

## Evidence

- `01-field-terminal-current.png` — current-run baseline before the contrast refinement.
- `02-field-terminal-refined.jpeg` — current-run simulator capture with the refined theme.

## Evidence limit

The simulator automation surface can validate launch, rendering, and single-pointer paths, but it cannot reproduce two independent physical finger contacts. The pan-feel and finger-lift handoff therefore still need a short physical-iPad acceptance check.
