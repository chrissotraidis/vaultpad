# Release build proof — 2026-07-18

## Scope

This checkpoint validates the unsigned device build and packaging path. It does not claim a signed install or physical-device runtime test.

## Device build

| Check | Result |
|---|---|
| SDK and configuration | `iphoneos`, Release |
| CPU | Mach-O arm64 |
| Minimum iPadOS | 15.0 |
| Device family | iPad only (`UIDeviceFamily = 2`) |
| Bundle | `com.chrissotraidis.vaultpad`, display name `VaultPad`, version 0.1.0 (1) |
| Orientation | Landscape left and right |
| Signing | Intentionally unsigned |
| Native product code | Swift bootstrap and settings sources compiled into the app target |
| Build result | `** BUILD SUCCEEDED **` |

## Archive

- File: `VaultPad-0.1.0-unsigned.ipa`
- Size: 3.4 MB
- SHA-256: `65a0e99d73682338bd41be9f24595507a991427d545a425c7f30dbae4f8e43ee`
- Checksum verification: pass
- Layout: `Payload/VaultPad.app` only; no `__MACOSX` or AppleDouble entries
- Included notices: `LICENSE.md` and `THIRD_PARTY_NOTICES.md`

## Repository and asset checks

`scripts/verify-repository.sh` passed against the built app. The verifier checks that:

- no `ref/`, save, IPA, `master.dat`, `critter.dat`, or numbered patch DAT is tracked;
- the bundle contains the executable, open-source `ce.dat`, license, and notices;
- no proprietary game or save data appears in the app bundle;
- the property list and shell scripts parse successfully;
- the VaultPad icon source exists.

The release packager repeats the archive-entry scan and rejects game data, saves, AppleDouble files, and `__MACOSX` metadata.

## Remaining release boundary

- The final clean-install Simulator matrix passed; see [2026-07-18-clean-install.md](2026-07-18-clean-install.md).
- Publish the local engine branch through an authorized fork and pin it in this repository so CI builds the tested implementation.
- Test signing and runtime on a physical iPad before presenting this as a device-validated release.
