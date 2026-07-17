# Report 5: Mod Compatibility

All URLs accessed 2026-07-17. Source evidence from upstream clone @ e97087b.

## Key facts (TL;DR)

1. **There are two fallout2-ce's.** Upstream `alexbatalov/fallout2-ce` is **no longer maintained** (fork maintainer stated this 2026-07-10 in [alexbatalov#521](https://github.com/alexbatalov/fallout2-ce/issues/521)). The **actively maintained fork is `github.com/fallout2-ce/fallout2-ce`** ("Fallout 2 Community Engine", last push 2026-07-17, continuous releases). Any iPad product should target the fork — dramatically better sfall coverage.
2. **Upstream sfall coverage partial/shallow**: 83 extender opcodes + 18 sfall_funcX metarules, arrays/lists/global-vars/global-scripts implemented, **no HOOK scripts**. Unimplemented opcode → programFatalError (longjmp abort) — mods silently break or crash.
3. **Fork has ~150 opcodes + ~62 metarules, full HOOK-script system (~28 hooks, ~15 declared unsupported)**, sfall-style `mods/` + `mods_order.txt`, maintained [SFALL_COMPATIBILITY.md](https://github.com/fallout2-ce/fallout2-ce/blob/main/SFALL_COMPATIBILITY.md). Reports itself as sfall 4.3.4.
4. **RPU is the fork's flagship target**: fork README "Restoration Project is supported (in Beta)"; maintainer mikeklaas: "CE is 99% compatible with RPU now… people are successfully playing" ([BGforge RPU#377](https://github.com/BGforgeNet/Fallout2_Restoration_Project/issues/377), 2026-07-10). On upstream, RP/RPU **does not work** without source hacks.
5. **Nevada and Sonora (original non-sfall versions) work today on both** — incl. 100%-completion report ([alexbatalov#249](https://github.com/alexbatalov/fallout2-ce/issues/249), anecdotal). Et tu, Olympus 2207, Resurrection: **not working**. Mutants Rising: never released — moot.
6. **Mod installation is pure file drops** — same on iOS as desktop: patch000–999.dat auto-loaded, data/ via master_patches, fork adds mods/*.dat. iOS works via File Sharing into Documents. German language data confirmed working on iOS ([fork#527](https://github.com/fallout2-ce/fallout2-ce/issues/527), anecdotal).
7. **Widescreen/HRP mods obsolete**: CE renders natively at arbitrary resolution. Upstream reads f2_res.ini; **fork migrates f2_res.ini → fallout2.cfg [screen]/[ui]** and supports HRP .edg files. Only f2_res.dat asset file optionally read (IFACE bar art).

## 1. Sfall implementation upstream (source evidence @ e97087b)

Files: sfall_config.cc (98 ln, ddraw.ini loader, [Misc]+[Scripts] only), sfall_opcodes.cc (1131 ln, **83 opcodes** 0x8156–0x827F), sfall_metarules.cc (291 ln, **18 metarules**: car_gas_amount, combat_data, critter_inven_obj2, dialog_obj, get/set_cursor_mode, get_flags/set_flags, get_object_data, get_text_width, intface_redraw, loot_obj, metarule_exist, outlined_object, set_ini_setting, set_outline, show_window, tile_refresh_display; unknown → programFatalError; unregistered opcode → "Undefined opcode" `interpreter.cc:2687`), sfall_arrays.cc (717 ln, full array engine), sfall_global_vars.cc (154 ln, save-format binary compatible), sfall_global_scripts.cc (220 ln — **global scripts gl*.int supported** via [Scripts] GlobalScriptPaths), sfall_lists.cc (144), sfall_ini.cc (197), sfall_kb_helpers.cc (297).

ddraw.ini keys read (sfall_config.h): [Misc] Male/FemaleDefaultModel/StartModel, StartYear/Month/Day, MainMenu offsets/colors, SkipOpeningMovies, StartingMap, Karma FRMs/Points/DisplayChanges, OverrideCriticalTable/File, RemoveCriticalTimelimits, BooksFile, ElevatorsFile, ConsoleOutputPath, PremadePaths/FIDs, ComputeSprayMod, Dynamite/PlasticExplosive damage, ExplosionsEmitLight, MovieTimer_artimer1–4, CityRepsList, UnarmedFile, DamageFormula, BonusHtHDamageFix, skill-FRM overrides, DialogueFix, TweaksFile, DialogGenderWords, TownMapHotkeysFix, ExtraGameMsgFileList, NumbersInDialogue, AutoQuickSave, VersionString, ConfigFile, PatchFile, PipBoyAvailableAtGameStart; [Scripts] IniConfigFolder, GlobalScriptPaths. README concedes "only a small subset… actually implemented" (README.md:107).

Missing upstream: **entire HOOK script system**, perks/traits opcodes (set_fake_perk etc.), knockback, fs_* VFS, shaders, direct memory read/write (impossible in reimplementation), interface drawing (draw_image, create_win), Hero Appearance, spatial/timer events, most gameplay-tweak setters.

Fork closes most: sfall_script_hooks.cc (1,091 ln), sfall_callbacks.cc, sfall_ext.cc, sfall_animation.cc; 150 opcodes, ~62 metarules. Hooks implemented: ToHit, AfterHitRoll, CalcAPCost, DeathAnim2, CombatDamage, OnDeath, UseObj(On), RemoveInvenObj, BarterPrice, ItemDamage, MoveCost, AmmoCost, KeyPress, MouseClick, UseSkill(On), Steal, WithinPerception, InventoryMove, InvenWield, AdjustFID, CombatTurn, StdProcedure(+End), RestTimer, GameModeChange, ExplosiveTimer, Encounter, CanUseWeapon. Not supported: direct memory, shaders, fs_*, DeathAnim1, FindTarget, CarTravel, SetGlobalVar, UseAnimObj/DescriptionObj/SetLighting ("Et tu"), Sneak, RollCheck, BestWeapon, BuildSfxWeapon, perk/trait + Hero Appearance ([fork#403](https://github.com/fallout2-ce/fallout2-ce/issues/403), [fork#195](https://github.com/fallout2-ce/fallout2-ce/issues/195)). Most ddraw.ini settings migrated to fallout2.cfg / <DAT>/config/game.cfg.

## 2. Restoration Project

- Upstream README: "not yet supported"; alexbatalov 2023-02-01 ([#229](https://github.com/alexbatalov/fallout2-ce/issues/229)). [#398](https://github.com/alexbatalov/fallout2-ce/issues/398) open: RPU v29 on upstream needed cherry-picks + hacks, then crashed in opStore. [#521](https://github.com/alexbatalov/fallout2-ce/issues/521) (2026-07-05): RP 2.3.3 CZ crash on Apple Silicon; response redirects to fork.
- Fork: README "**Restoration Project is supported (in Beta)**". [fork#196 RPU tracker](https://github.com/fallout2-ce/fallout2-ce/issues/196) nearly all checked; remaining: set_fake_perk (EPA display-only), fs_* (optional), set_hero_style. Recent RPU fixes: [fork#510](https://github.com/fallout2-ce/fallout2-ce/issues/510) (fs_copy, closed 2026-07-09), [fork#467](https://github.com/fallout2-ce/fallout2-ce/issues/467) (closed).
- BGforge RPU does not document CE compat (installer assumes bundled sfall); [RPU#377](https://github.com/BGforgeNet/Fallout2_Restoration_Project/issues/377) closed 2026-03-06; mikeklaas "99% compatible" 2026-07-10.
- killap RP 2.3.3: treat as "RPU status applies, less tested."

## 3. Other majors

| Mod | Upstream | Fork | Evidence |
|---|---|---|---|
| Fallout: et tu (rotators/Fo1in2) | Does not work ([#166](https://github.com/alexbatalov/fallout2-ce/issues/166)) | Does not work yet (missing hooks/perks.ini; NovaRain 2024-10-19 [Fo1in2#274](https://github.com/rotators/Fo1in2/issues/274)) | Strong |
| Fallout 1.5: Resurrection | Does not work ([#403](https://github.com/alexbatalov/fallout2-ce/issues/403) — broken UI/maps) | Unknown/untested | Weak |
| Fallout: Nevada (orig) | **Works with config tweaks** (MovieTimer_artimer4, start date; [#441](https://github.com/alexbatalov/fallout2-ce/issues/441), [#189](https://github.com/alexbatalov/fallout2-ce/issues/189), [roginvs Nevada notes](https://github.com/roginvs/fallout2-ce/blob/main/os/web/README.md)) | Works; bugs fixed | Medium, anecdotal |
| Fallout: Sonora 1.10 | **Works** (100% completion, [#249](https://github.com/alexbatalov/fallout2-ce/issues/249)) | Works; open edge cases ([fork#126](https://github.com/fallout2-ce/fallout2-ce/issues/126)) | Medium, anecdotal |
| Olympus 2207 | Does not work ([#200](https://github.com/alexbatalov/fallout2-ce/issues/200) checklist, [#300](https://github.com/alexbatalov/fallout2-ce/issues/300)) | Boots then crashes (mikeklaas 2026-04-21) | Strong |
| Mutants Rising | Never released | — | Strong |
| HRP/widescreen | Obsolete (built-in) | Obsolete (+.edg) | Strong (source) |
| Language packs | Works (data-level) | Works; German-on-iOS confirmed ([fork#527](https://github.com/fallout2-ce/fallout2-ce/issues/527)) | Medium, anecdotal |
| UP/UPU | Likely works, unverified | Expected (subset of RPU), unverified | Weak/inferred |

## 4. Installation mechanics

- gameDbInit (`game.cc:1322-1387`): master.dat(+master_patches), critter.dat(+critter_patches), patch000–999.dat (template via Misc.PatchFile), f2_res.dat. Patch DATs + fan translations load normally.
- Loose files: data/ via master_patches. Upstream bug: fully unpacked patch dirs break saving ([#334](https://github.com/alexbatalov/fallout2-ce/issues/334), open).
- **mods/ folder: upstream has none. Fork implements** sfall 4.x-style mods/ + mods_order.txt (sfall_ext.cc sfallLoadMods(); order master_patches > critter_patches > mods > patchXXX.dat > ce.dat > f2_res.dat > critter.dat > master.dat) — exactly how RPU ships (mods/rpu.dat + rpu.ini). Fork adds its own required archive **ce.dat**, supports .zip-format DATs and .ogg/.wav/.png assets.
- Language: fallout2.cfg language + language_filter keys; localized art paths.

## 5. Resolution/widescreen

- Upstream: f2_res.ini ([MAIN]/[IFACE]/[STATIC_SCREENS]); README gives iPad-points guidance (README.md:91-103).
- Fork: **migrates f2_res.ini → fallout2.cfg [screen] resolution_x/y, windowed, scale; [ui] extras incl. iOS-only quick_toolbar_visible**; supports HRP .edg files. IFACE side art needs f2_res.dat (they host one).
- Verdict: HRP DLL/widescreen mods obsolete under CE.

## 6. iOS angle

- Mods = same file-drop mechanism via Files/Finder into Documents. Nothing differs on iOS except transfer channel + case sensitivity (lowercase).
- **Fork README documents refined iPad controls (three-finger ESC, four-finger quicksave, HUD direct-touch) and iOS-only settings — fork is actively developed with iPad in mind.** Open fork issue [#398](https://github.com/fallout2-ce/fallout2-ce/issues/398) (touch issues iPad/Android); upstream [#508](https://github.com/alexbatalov/fallout2-ce/issues/508) requests absolute pointer input on iPad; roginvs PR #304 tap-to-point never merged upstream.
- Android adjacent: Nevada exposed real engine bugs (fixed); TC unpacking "up to 20 minutes"; Nevada save issues ([#250](https://github.com/alexbatalov/fallout2-ce/issues/250), closed). iOS heap segfault under investigation ([fork#529](https://github.com/fallout2-ce/fallout2-ce/issues/529), open 2026-07-16).

## 7. Recommendation

Base the iPad product on the **maintained fork (fallout2-ce/fallout2-ce)**: RPU-beta, hook scripts, mods/ loader, active iPad-focused development. V1 scope: vanilla + UP-class data mods + language packs supported (file-drop via Files); RPU as experimental/beta opt-in; defer TCs requiring deep sfall (et tu, Olympus, Resurrection) — engine-bound, not packaging-bound. Nevada/Sonora as "known-working community content" with canned config presets (two ini keys). Defer in-app mod-manager UI to v1.x; v1 needs documented mods/ + data/ via File Sharing (engine already honors).

Community context (anecdotal): [NMA "Reintroducing Fallout: CE"](https://www.nma-fallout.com/threads/reintroducing-fallout-ce.223312/), [fallout.wiki CE page](https://fallout.wiki/wiki/Mod:Fallout_2_Community_Edition), [iMore iPad article](https://www.imore.com/ipad/ipad-pro-guru-users-github-hack-to-get-fallout-2-running-on-apples-touchscreen-tablet).
