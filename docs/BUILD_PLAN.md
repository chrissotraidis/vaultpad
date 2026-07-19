# VaultPad build plan

This is the execution contract for building VaultPad from the product requirements in [PRD.md](PRD.md). The work runs as a proof-gated loop: implement the smallest complete slice, build it, test it, play it, record defects, fix the highest-impact defect, and checkpoint the proven state to GitHub.

## Goal

Ship a neutral-branded, reproducible iPadOS application that lets a user import their own Fallout 2 data, starts without hand-edited configuration, is fully playable with touch, safely survives normal iPad lifecycle events, and has been playtested on iPad Simulator with the supplied local reference data.

## Milestones and gates

1. **Baseline engine proof**
   - Pin the active `fallout2-ce/fallout2-ce` engine.
   - Build unchanged for macOS, iOS Simulator, and unsigned iOS device where supported.
   - Launch on an iPad Simulator and record the exact baseline behavior.
   - Gate: reproducible build commands and a simulator launch artifact.

2. **Product bootstrap**
   - Add VaultPad presets, signing-safe configuration, setup/build scripts, tests, and CI.
   - Use neutral bundle identity, display name, and original product shell.
   - Gate: clean clone to generated Xcode project without committing credentials or game data.

3. **First-run product experience**
   - Add native import, validation, case-normalizing copy, progress, recoverable errors, bundled `ce.dat`, and automatic display configuration.
   - Gate: fresh simulator install imports the supplied reference folder and reaches the game with no manual file/config editing.

4. **iPad reliability**
   - Add background/foreground safety, autosave/config flush, audio-session handling, save import/export, and complete text/numeric input.
   - Gate: lifecycle and save/load regression matrices pass.

5. **Touch controls and playtest loop**
   - Implement persistent Hybrid, Direct Touch, and Trackpad modes.
   - Preserve long-press/right-click and two-finger scrolling; fix coordinate, ordering, sensitivity, and small-target problems.
   - Repeatedly play character creation, Temple of Trials, combat, dialogue, barter, inventory, world map, save/load, and background/resume on iPad Simulator.
   - Gate: every required flow can be completed touch-only with no blocking control defect.

6. **Release proof**
   - Run automated tests, builds, long-session smoke checks, legal/asset scans, documentation checks, and the complete acceptance matrix.
   - Produce an unsigned IPA/checksum and installation documentation.
   - Gate: release checklist is green, known limitations are explicit, and all tested commits are pushed.

## Working loop

For every slice:

1. Define the observable behavior and the fastest failing test.
2. Implement only the code needed for that behavior.
3. Run focused tests, then the relevant platform build.
4. Install/launch on iPad Simulator and exercise the behavior through the UI.
5. Capture defects and evidence in `docs/playtests/`.
6. Fix and repeat until the slice's gate is green.
7. Commit and push the checkpoint before starting a materially different slice.

## Non-negotiable constraints

- Never commit or distribute anything under `ref/` or any other proprietary game asset.
- Never put credentials, signing identities, or provisioning material in Git.
- Keep engine changes small and upstreamable; keep VaultPad branding/product code outside the engine where practical.
- Do not claim physical-device, pointer-hardware, battery, TestFlight, or App Store proof when only Simulator evidence exists.
- Prefer small reversible changes, and rerun affected controls after any input rewiring.
