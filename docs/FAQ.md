# VaultPad FAQ

## Does VaultPad include the game?

No. VaultPad contains the engine source, native iPad product layer, and original app artwork. You must select data from a legally purchased copy on first launch. The import stays on the device.

## Which iPads are supported?

The app targets iPadOS 15 or newer and iPad only. The current deep test profile is an 11-inch iPad Pro Simulator on iPadOS 18.5. A real arm64 device build succeeds, but physical-device runtime, battery, thermals, hardware pointers, and interruption handling are not yet certified.

## Where are saves stored?

Inside VaultPad's Documents container under `data/SAVEGAME/`. App updates preserve the container; deleting the app deletes it.

## How do I protect saves before deleting the app?

Open `SET` → **Export Saves…** → **Save to Files**. VaultPad creates a standard ZIP. After reinstalling and importing the game data, expand the ZIP in Files, start a game, open `SET` → **Import Save Folder…**, and select the expanded folder. The full clean-reinstall recovery chain is recorded in [`docs/playtests/2026-07-18-save-recovery.md`](playtests/2026-07-18-save-recovery.md).

## I hid the quick toolbar. How do I get it back?

Tap the compact `SET` tab above the HUD, choose **Toolbar on**, save, and restart VaultPad.

## Why is the IPA unsigned?

VaultPad has no distribution certificate or provisioning profile in the repository. The release script deliberately creates an unsigned arm64 IPA for private signing or sideloading. See [`docs/INSTALL.md`](INSTALL.md).

## Can I use mods?

Vanilla, Unofficial Patch-class updates, and compatible language packs are the supported V1 boundary. Restoration Project Updated is experimental; total conversions that need unsupported sfall behavior are not promised. See [`docs/MODS.md`](MODS.md).

## Is VaultPad affiliated with the rights holders?

No. VaultPad is unofficial, free, and non-commercial, and is not affiliated with Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc.
