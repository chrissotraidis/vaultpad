# Install VaultPad

VaultPad is an iPadOS developer preview. The downloadable IPA is unsigned and requires your own Apple account and signing/sideloading tool. You also need data from a legally purchased copy of Fallout 2. The repository and release artifact contain no game data.

## Download the unsigned IPA

Download `VaultPad-0.1.0-preview.1-unsigned.ipa` and its checksum from the [latest GitHub release](https://github.com/chrissotraidis/vaultpad/releases/latest). Verify the download, then install it with a signing/sideloading tool that uses your Apple account:

```bash
shasum -a 256 -c VaultPad-0.1.0-preview.1-unsigned.ipa.sha256
```

VaultPad does not supply credentials, certificates, provisioning profiles, or a signing service.

## Build from source

Building VaultPad requires macOS, Xcode, CMake 3.25 or newer, Git, and an Apple account.

## Prepare the checkout

```bash
git clone --recursive https://github.com/chrissotraidis/vaultpad.git
cd vaultpad
./scripts/setup.sh
```

The first configure may download the engine's pinned open-source dependencies.

## iPad Simulator

List available iPad Simulators and copy the UDID you want to use:

```bash
xcrun simctl list devices available
```

Build the app, then install it on the selected Simulator:

```bash
./scripts/build-simulator.sh Release
./scripts/install-simulator.sh YOUR-SIMULATOR-UDID
```

First launch presents VaultPad's importer. Choose the folder containing `master.dat` and `critter.dat`; `patch000.dat` and a `data` folder are imported when present. Import happens locally inside the Simulator container.

## Unsigned device artifact

Create an unsigned arm64 app and IPA:

```bash
./scripts/package-release.sh 0.1.0-preview.1 Release
```

The output is `out/release/VaultPad-0.1.0-preview.1-unsigned.ipa` with a sibling SHA-256 file. Verify it before use:

```bash
cd out/release
shasum -a 256 -c VaultPad-0.1.0-preview.1-unsigned.ipa.sha256
```

The IPA is intentionally unsigned. Install it with a signing/sideloading tool that uses your Apple account, or sign and run the generated device project in Xcode. VaultPad does not supply credentials, certificates, or provisioning profiles.

## Sign from Xcode

Add your Apple development team to the ignored `ios/Config/Signing.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = YOURTEAMID
CODE_SIGN_STYLE = Automatic
```

Build and open the generated device project:

```bash
./scripts/build-device.sh Debug
open out/build/engine-ios-device/fallout2-ce.xcodeproj
```

In Xcode, select the `fallout2-ce` target, enable automatic signing, choose your Development Team under Signing & Capabilities, select an attached iPad, and Run. If your account cannot use `com.chrissotraidis.vaultpad`, choose a unique bundle identifier for your private build in `ios/Config/VaultPad.xcconfig`.

## Game data and saves

- Game data is copied into VaultPad's private Documents container and is never uploaded.
- Deleting the app deletes its container. Export saves from VaultPad Settings before uninstalling a device build.
- Reinstalling over an existing build preserves the container.
- The app's Settings screen can export saves as a ZIP and import validated `SAVEGAME/SLOTxx` folders.

## Current test boundary

Simulator builds have run on 11-inch and 13-inch iPad Pro profiles. Signed development builds have also been installed, updated in place, launched, and played on a physical 12.9-inch iPad Pro (6th generation). Hardware keyboard/mouse behavior, broad device coverage, battery and thermal behavior, TestFlight, and App Store installation are not certified. See [TESTING.md](TESTING.md).
