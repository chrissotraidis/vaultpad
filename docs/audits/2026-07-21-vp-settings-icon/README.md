# VP settings badge regression check — 2026-07-21

## Decision

Replace the in-game `Settings` label with a compact settings cog plus `VP` field-terminal badge. The shipped badge is rendered with Fallout's native indexed palette and pixel font so it stays crisp at the 640×480 interface resolution. Its 46×24 game-pixel button remains materially smaller than the old text button while preserving a practical touch target. The final badge keeps three clear game pixels between the cog and the `VP` monogram.

## Visual target

`vp-badge-concept.png` was generated with the built-in image generator as a style target. Final prompt:

> A compact late-1990s post-apocalyptic computer-game HUD badge containing the exact uppercase letters VP, with a dark charcoal/olive metal face, muted brass border, aged gold letters, and two tiny rivets. Crisp low-resolution pixel art, readable around 30×20 pixels; no gear, wrench, modern glossy styling, pill shape, proprietary logo, extra text, or watermark.

The runtime implementation retains the concept's dark plaque, brass inner frame, clipped corners, and gold `VP`, then adds a clear eight-tooth settings cog. It uses the engine's existing palette and font rather than shipping a mismatched high-resolution bitmap.

## Sanity checks

1. **Build — passed.** Debug iPad simulator build completed successfully.
2. **Gameplay rendering — passed.** The cog reads as settings, the complete `VP` monogram remains legible, and the badge stays aligned with the command row without crowding the adjacent action button.
3. **Tap wiring — passed.** Tapping the VP badge opens `VAULTPAD // FIELD TERMINAL`.
4. **Modal isolation — passed.** Tapping the badge location while Fallout's pause/options modal is active does not open VaultPad settings behind the modal.
5. **Collapsed-bar path — source/build checked.** `Settings Only` continues to expose the same settings action, now rendered as the VP badge.
6. **Combat wording — passed.** The current action uses plain language (`Punch - Cost 3`), while the alternate action is labeled `Next: Strong Kick`; both fit at gameplay scale without clipping.

## Evidence

- `01-vp-badge-gameplay.jpeg` — badge in the live command bar.
- `02-vp-opens-field-terminal.jpeg` — Field Terminal opened from the badge.
- `03-cog-vp-badge-gameplay.jpeg` — final cog-plus-VP settings badge in gameplay.
- `04-spaced-vp-clear-cost-labels.jpeg` — final spacing and plain-language action labels in the rebuilt simulator app.
- `05-spaced-vp-opens-field-terminal.png` — the final badge successfully opening the themed Field Terminal.
- `vp-badge-concept.png` — generated visual target.

## Evidence limit

The simulator's macOS automation surface can click the engine-rendered game UI but does not expose the separate SwiftUI settings window as clickable accessibility elements. The VP-to-Field-Terminal transition and modal isolation were exercised directly, and the opened terminal was captured from the simulator display; the native Cancel and Apply actions remain covered by their existing shared close/reset path and the successful build.
