# VaultPad

VaultPad is a neutral, touch-first iPad app for running Fallout 2 Community Edition with game data supplied by the user.

> Status: local beta validated on an 11-inch iPad Pro Simulator running iPadOS 18.5. Native onboarding, touch controls, lifecycle saves, dialogue, barter, combat, inventory, and world-map travel have been exercised through the real game UI. Physical-device, hardware pointer, TestFlight, and App Store testing remain open.

VaultPad contains no Fallout game content. First launch asks for the folder from a legally purchased copy, validates the required files, and copies them into the app's private Documents container. Nothing is downloaded or uploaded.

## What works

- Native Files-based first-run import with validation and recoverable errors.
- Automatic iPad display configuration with Comfort and Native presets.
- Direct, Hybrid, and Trackpad touch modes with persistent sensitivity.
- Touch-native combat, inventory, dialogue, barter, quantity entry, and world-map travel.
- Background quicksave, foreground audio recovery, and save import/export.
- Original VaultPad name, icon, onboarding, settings, and legal notices.
- Reproducible Simulator and unsigned arm64 device builds.

The playtest record is in [`docs/playtests/`](docs/playtests/), including the [quick-toolbar clarity audit](docs/audits/2026-07-18-toolbar/README.md), and the acceptance loop is in [`docs/BUILD_PLAN.md`](docs/BUILD_PLAN.md). See [`docs/CONTROLS.md`](docs/CONTROLS.md) for the touch map, [`docs/MODS.md`](docs/MODS.md) for the supported mod boundary, and [`docs/FAQ.md`](docs/FAQ.md) for recovery and distribution answers.

## Build and run

Requirements: macOS, Xcode, CMake 3.25 or newer, and a recursive checkout.

```bash
./scripts/setup.sh
./scripts/build-simulator.sh Release
./scripts/install-simulator.sh
```

Build an unsigned arm64 device app and IPA:

```bash
./scripts/build-device.sh Release
./scripts/package-release.sh 0.1.0 Release
```

Artifacts are written under `out/`, which is ignored by Git. See [`docs/INSTALL.md`](docs/INSTALL.md) for signing, Simulator selection, and sideloading notes.

## Repository map

| Path | Purpose |
|---|---|
| `engine/` | Pinned engine snapshot from this repository's `engine-vaultpad` branch |
| `ios/Launcher/` | Native onboarding, importer, settings, saves, and lifecycle shell |
| `ios/Assets.xcassets/` | Original VaultPad app artwork |
| `scripts/` | Setup, Simulator/device builds, packaging, and repository checks |
| `docs/PRD.md` | Product and acceptance contract |
| `docs/playtests/` | Dated Simulator evidence and remaining limitations |

## Legal

VaultPad is unofficial, free, and non-commercial. It is not affiliated with, endorsed, or sponsored by Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc.

The app distributes no game assets. Users must provide data from a legally purchased copy. Engine code derives from Fallout 2 Community Edition under the included [Sustainable Use License](LICENSE.md); dependency notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). This is not legal advice.

The original feasibility research remains available under [`docs/research/`](docs/research/).
