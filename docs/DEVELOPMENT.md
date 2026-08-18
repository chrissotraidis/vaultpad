# VaultPad development

VaultPad is a thin iPad product layer around a pinned Fallout 2 Community Edition engine revision. Keep product code, engine changes, and user-supplied game data in their existing boundaries.

## Repository layout

| Path | Purpose |
| --- | --- |
| `engine/` | Nested engine checkout pinned by the root repository |
| `ios/Launcher/` | Native onboarding, Field Terminal, saves, and lifecycle integration |
| `ios/Assets.xcassets/` | Original VaultPad artwork |
| `ios/Config/` | Public build settings and ignored local signing configuration |
| `scripts/` | Reproducible setup, build, packaging, and safety checks |
| `docs/` | Current user and contributor documentation |
| `ref/` | Optional local-only game-data staging directory; ignored by Git |

The `engine` submodule points to the `engine-vaultpad` branch in this repository. An engine change must be committed and pushed there before the root repository updates its pinned engine revision.

## Fast development loop

Prepare a fresh checkout:

```bash
git clone --recursive https://github.com/chrissotraidis/vaultpad.git
cd vaultpad
./scripts/setup.sh
```

Build and launch in an iPad Simulator:

```bash
./scripts/build-simulator.sh Debug
xcrun simctl list devices available
./scripts/install-simulator.sh YOUR-IPAD-SIMULATOR-UDID
```

Build the unsigned arm64 device app:

```bash
./scripts/build-device.sh Debug
open out/build/engine-ios-device/fallout2-ce.xcodeproj
```

Add your Apple development team in the ignored `ios/Config/Signing.xcconfig`, then use Xcode to sign and run on an attached iPad. Full installation instructions are in [INSTALL.md](INSTALL.md).

## Required checks

Run these before proposing a change:

```bash
./scripts/verify-repository.sh
./scripts/build-simulator.sh Debug
```

For changes affecting signing, packaging, onboarding, or bundled resources, also run:

```bash
./scripts/package-release.sh 0.1.0-preview.1 Release
```

Touch changes require UI regression testing. Use the focused checklist in [TESTING.md](TESTING.md), then verify the affected gesture on a physical iPad whenever the behavior depends on real multi-touch input.

## Contribution rules

- Never commit game data, saves, signed IPAs, certificates, provisioning profiles, or Apple credentials.
- Preserve the direct-touch, two-finger-pan, and legacy pointer modes when changing shared input code.
- Keep the VaultPad dock clear of Fallout's original HUD and status-indicator row.
- Treat Simulator results as build and UI evidence, not a substitute for physical gesture acceptance.
- Keep changes small, rerun affected controls after input rewiring, and document remaining limitations honestly.
