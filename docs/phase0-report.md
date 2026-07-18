# Phase 0 verification report

Date: 2026-07-18

## Environment

- macOS host with Apple-silicon-compatible Xcode toolchain
- Xcode 26.6 (build 17F113)
- CMake 4.4.0
- Ninja 1.13.2
- iOS Simulator runtimes: 18.5 and 26.5
- Available iPad profiles include 11-inch and 13-inch Pro, Air, mini, and base iPad

## Engine baseline

- Source: `fallout2-ce/fallout2-ce`
- Pinned commit: `d8d99fe94a8497e150e569f1471424dc0148333a`
- Active-fork state observed on 2026-07-18:
  - SDL is already pinned to 2.32.8, newer than the PRD's audited 2.26.1 baseline.
  - Direct-touch state, iPad quick toolbar, HUD tap-through, and screen-specific touch modes already exist.
  - Numeric inventory/barter input still lacks an explicit text-input call.
  - There is still no committed iOS Simulator preset.

## Baseline build

Commands:

```sh
cd engine
cmake --preset macos
cmake --build --preset macos-debug --parallel 8
```

Result: **pass** under Xcode 26.6. The universal macOS app, `ce.dat`, engine tools, and mapper built successfully. Existing precision warnings were emitted, but there were no build errors.

## Simulator inventory

CoreSimulator access was verified outside the workspace sandbox. Primary playtest destinations:

- iPad Pro 11-inch (M4), iOS 18.5
- iPad Pro 13-inch (M5), iOS 26.5
- iPad mini (A17 Pro), iOS 18.5/26.5

## Simulator build and launch

The engine was configured with `CMAKE_OSX_SYSROOT=iphonesimulator` and built successfully as an arm64 iOS Simulator application. The checked-in `scripts/build-simulator.sh` and `scripts/install-simulator.sh` path then passed end to end: configure, build, install, private data import, and launch. It was installed on the 11-inch iPad Pro (M4), iOS 18.5 profile with the visible name **VaultPad** and bundle id `com.chrissotraidis.vaultpad`.

The no-data launch reached the expected missing-asset alert. After copying only the supplied local game data into the private simulator container, the build reached the main menu, character selection, and the Temple of Trials. Detailed evidence and input defects are recorded in [the baseline playtest](playtests/2026-07-18-baseline.md).

## Remaining product gates

- Publish the verified local engine touch commit to the user-owned engine fork.
- Add persistent Hybrid, Direct Touch, and Trackpad gameplay modes.
- Complete the remaining combat, inventory, barter, save/load, and lifecycle matrix.

Physical-device, Magic Keyboard, Bluetooth mouse, battery, TestFlight, and App Store results remain unverified until real hardware/services are used.
