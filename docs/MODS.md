# Mod compatibility

VaultPad runs the Fallout 2 Community Edition data loader. It does not download, bundle, or endorse third-party game data.

## V1 support boundary

| Content | Status |
| --- | --- |
| Vanilla legally purchased game data | Primary support target; exercised through the current touch-playtest path |
| Unofficial Patch-class data updates | Supported when supplied as normal patch DAT / loose-data files |
| Language packs | Supported when compatible with the base game and Community Edition |
| Restoration Project Updated | Experimental; engine support exists, but iPad parity is not certified |
| Total conversions requiring deep sfall behavior | Unsupported unless their own documentation explicitly confirms Community Edition compatibility |

## Installing files

The first-run importer copies `master.dat`, `critter.dat`, optional `patch000.dat`, and an optional `data/` directory. For later additions, use the Files app or Finder file sharing to place compatible files in VaultPad's Documents directory:

- numbered patch archives: `patch000.dat` through `patch999.dat`;
- loose overrides under `data/`;
- engine-compatible packages under `mods/`, with `mods_order.txt` when the package requires an explicit order.

Keep the filename case and directory structure supplied by the mod. Restart VaultPad after changing data files.

## Safety

Export saves before changing a mod set. Do not reuse a long-running save after removing content it depends on. Mod script crashes and save incompatibilities are outside VaultPad's vanilla release guarantee.

Compatibility beyond vanilla data remains evidence-bound. When reporting a mod issue, include the exact mod version, installation layout, and whether the same data works in Fallout 2 Community Edition on another platform.
