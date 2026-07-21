# VaultPad FAQ

## Does VaultPad include the game?

No. VaultPad contains the engine source, native iPad product layer, and original app artwork. You must select data from a legally purchased copy on first launch. The import stays on the device.

## Which iPads are supported?

The app targets iPadOS 15 or newer and iPad only. Simulator coverage includes 11-inch and 13-inch iPad Pro profiles, and the current physical test device is a 12.9-inch iPad Pro (6th generation). Battery, thermals, hardware pointers, and long-session interruption handling are not yet certified.

## Where are saves stored?

Inside VaultPad's Documents container under `data/SAVEGAME/`. App updates preserve the container; deleting the app deletes it.

## How do I protect saves before deleting the app?

Open **Settings** → **Export Saves…** → **Save to Files**. VaultPad creates a standard ZIP. After reinstalling and importing the game data, expand the ZIP in Files, start a game, open **Settings** → **Import Save Folder…**, and select the expanded folder. The full clean-reinstall recovery chain is recorded in [`docs/playtests/2026-07-18-save-recovery.md`](playtests/2026-07-18-save-recovery.md).

## I hid the quick toolbar. How do I get it back?

Tap the compact **Settings** control above the HUD, choose **Full Bar** under **Gameplay Command Bar**, then choose **Apply & Return**. Touch controls update immediately.

## Why is the IPA unsigned?

VaultPad has no distribution certificate or provisioning profile in the repository. The release script deliberately creates an unsigned arm64 IPA for private signing or sideloading. See [`docs/INSTALL.md`](INSTALL.md).

## Can I use mods?

Vanilla, Unofficial Patch-class updates, and compatible language packs are the supported V1 boundary. Restoration Project Updated is experimental; total conversions that need unsupported sfall behavior are not promised. See [`docs/MODS.md`](MODS.md).

## Is VaultPad affiliated with the rights holders?

No. VaultPad is unofficial, free, and non-commercial, and is not affiliated with Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc.
