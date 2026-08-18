# VaultPad FAQ

## Does VaultPad include the game?

No. VaultPad contains the engine source, native iPad product layer, and original app artwork. You must select data from a legally purchased copy on first launch. The import stays on the device.

## Which iPads are supported?

The app targets iPadOS 15 or newer and iPad only. Simulator coverage includes 11-inch and 13-inch iPad Pro profiles, and signed builds have been installed and played on a 12.9-inch iPad Pro (6th generation). Broader device coverage, battery, thermals, hardware pointers, and long-session interruption handling are not yet certified.

## Where are saves stored?

Inside VaultPad's Documents container under `data/SAVEGAME/`. App updates preserve the container; deleting the app deletes it.

## How do I protect saves before deleting the app?

Open the VaultPad Field Terminal → **Export Saves…** → **Save to Files**. VaultPad creates a standard ZIP. After reinstalling and importing the game data, expand the ZIP in Files, start the game, open the Field Terminal → **Import Save Folder…**, and select the expanded folder.

## I hid the VaultPad dock. How do I get it back?

Tap the gear-and-VP badge above the HUD, choose **Full Dock** under **VaultPad Dock**, then choose **Apply & Return**.

## How do I download VaultPad?

Download the unsigned arm64 IPA from the [latest GitHub release](https://github.com/chrissotraidis/vaultpad/releases/latest), then sign and sideload it with your own Apple account. VaultPad does not publish a pre-signed binary or signing service. See [INSTALL.md](INSTALL.md).

## Can I use mods?

Vanilla, Unofficial Patch-class updates, and compatible language packs are the supported first-release boundary. Restoration Project Updated is experimental; total conversions that need unsupported sfall behavior are not promised. See [MODS.md](MODS.md).

## Is VaultPad affiliated with the rights holders?

No. VaultPad is unofficial, free, and non-commercial, and is not affiliated with Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc.
