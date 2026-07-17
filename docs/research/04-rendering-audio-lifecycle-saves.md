# Report 4: Rendering / Display / Audio / Lifecycle / Filesystem / Saves

Audited at HEAD e97087b9 (2025-02-16), bundle version 1.3.0. SDL2 2.26.1 vendored statically.

## Key facts (TL;DR)

- **Renderer**: single SDL_Window + SDL_Renderer + one streaming texture. 8-bit palettized SW surface → 32-bit SDL_PIXELFORMAT_RGB888 surface (CPU blit) → SDL_UpdateTexture (full frame, every present) → SDL_RenderCopy scaled by SDL_RenderSetLogicalSize (aspect-preserving letterbox). On iOS renderer resolves to **Metal via SDL fallback** (code hints "opengl", which doesn't exist on iOS). No vsync flag; 60 FPS sleep-based limiter.
- **Resolution**: default **640x480**; overridden only by hand-edited f2_res.ini (MAIN/SCR_WIDTH, SCR_HEIGHT, WINDOWED, SCALE_2X). **No code queries display size on any platform.** Arbitrary internal resolutions supported (min 640x480 when SCALE_2X used).
- **UI scaling**: none, except integer SCALE_2X. All UI windows fixed-size 640x480-era art, centered; higher res = smaller UI. Interface bar supports Mash-HRP-style keys (IFACE_BAR_MODE/WIDTH/SIDE_ART/SIDES_ORI) and HR_IFACE_*.FRM art, falls back to 640 if art missing.
- **Touch coordinate hazard**: fingers mapped normalized × internal-resolution, ignoring logical-size letterbox offsets (`src/touch.cc:102-103`) — internal aspect must match display aspect or touch is skewed.
- **Audio**: one SDL device, 22050 Hz / S16 / stereo / 1024-sample callback; per-buffer SDL_AudioStream + SDL_MixAudioFormat; in-repo ACM decoder (`src/sound_decoder.cc`). **No AVAudioSession, no interruption handling**; pause/resume tied solely to SDL_WINDOWEVENT_FOCUS_LOST/GAINED.
- **Lifecycle**: **zero** SDL_APP_* / SDL_AddEventWatch / SDL_SetEventFilter / SDL_iPhoneSetAnimationCallback usage. Blocking while main loop. On focus loss engine busy-waits in `_GNW95_lost_focus()` (125 ms poll). No save-on-background; suspended-then-killed app loses unsaved progress.
- **Filesystem**: iOS `chdir()`s into app-sandbox **Documents** at startup; everything relative to it. UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace → Files app / Finder sharing works. Saves in `Documents/<master_patches>/SAVEGAME/SLOTxx/` (default data/SAVEGAME) → preserved across updates, deleted on uninstall.
- **Case sensitivity**: fully handled — per-component case-insensitive scan (`compat_resolve_path`); DAT lookups case-insensitive bsearch. Works on case-sensitive iOS APFS at per-open readdir cost.
- **Config**: reads fallout2.cfg (auto-created with defaults on first clean exit), f2_res.ini (read-only, never generated), ddraw.ini (read-only, never generated).
- **Portability**: 64-bit clean in audited areas; assumes little-endian host (fine arm64). Effectively single-threaded + SDL audio callback thread (recursive_mutex guarded).
- **Multiplayer: none.** No sockets, no SDL_net.

## 1. Rendering (`src/svga.cc`)

Window creation `_GNW95_init_window()` `svga.cc:173-200`: hint RENDER_DRIVER="opengl" (:176); flags SDL_WINDOW_OPENGL|SDL_WINDOW_ALLOW_HIGHDPI (:178); +FULLSCREEN if fullscreen (:181, default true `svga.cc:104`, disabled only by f2_res.ini WINDOWED). SDL_CreateWindow at width*scale (:184).

- HIGHDPI set; drawable native pixel scale; logical-size pipeline absorbs it.
- `createRenderer()` `svga.cc:357-384`: SDL_CreateRenderer(gSdlWindow, -1, 0) (:359) — no PRESENTVSYNC. "opengl" hint invalid on iOS → SDL falls back to **Metal** first. Works but accidental; no iOS-specific render code.
- Scaling: SDL_RenderSetLogicalSize(width,height) (:364) — aspect-preserving letterbox. No integer-scale, no scale-quality hint (default nearest).

Streaming pipeline: `directDrawInit()` :203-231 (8-bit palettized gSdlSurface); `createRenderer()` :368 (RGB888 STREAMING texture) + :378 (matching 32-bit gSdlTextureSurface). Dirty-rect blits via `_GNW95_ShowRect()` :301-315. Palette animation (:243-278) re-blits ENTIRE surface per palette change (Fallout color-cycles constantly → per-frame full-frame CPU conversion in practice). `renderPresent()` :410-416 full-frame UpdateTexture+RenderCopy+Present, called from main loop and every modal sub-loop (`main.cc:350,400,459`).

Internal resolution decided in `_GNW95_init_mode_ex()` `svga.cc:102-164`: boot chain hardwires 640x480 (`game.cc:150` → `window.cc:1375` → `window.cc:88-100` → _init_vesa_mode(640,480)). f2_res.ini overrides SCR_WIDTH/HEIGHT (:109-118), WINDOWED (:120-123), SCALE_2X (:125-135 — divides internal res by 2, window at width*scale, refused if <640x480). IFACE keys (:137-140).

**No display-size query exists**: zero hits for SDL_GetCurrentDisplayMode / SDL_GetDisplayBounds / SDL_GetDisplayUsableBounds / SDL_GetRendererOutputSize / SDL_GL_GetDrawableSize. README.md:100-103 tells tablet users to type device logical resolution (iPad Pro 11 = 834x1194 points).

640x480 assumptions survive as minimums/centering: death screen (`main.cc:46-47,373-380`), main menu (`mainmenu.cc:23-24,97-102`), dboxes offset (screenGetWidth()-640)/2 (`dbox.cc:210,600,965`), pipboy/loadsave centered (`pipboy.cc:549`, `loadsave.cc:1365`). World view resolution-aware (`map.cc:183`).

Safe areas: nothing; UIStatusBarHidden=true, UIRequiresFullScreen=true (Info.plist:37-40). Fine on rectangular iPads; would clip under camera housings.

Orientation: Info.plist:41-50 landscape-only (both idioms). No SDL_HINT_ORIENTATIONS in src/.

Resize: SDL_WINDOWEVENT_SIZE_CHANGED → handleWindowSizeChanged (`input.cc:942-944` → `svga.cc:404-408`) recreates renderer/texture at same internal res. Window never resizable; UIRequiresFullScreen blocks Split View.

## 2. High-res UI / HRP integration

- CE integrates a **subset** of Mash HRP conventions: reads f2_res.ini, honors 4 IFACE keys, auto-mounts `f2_res.dat` if present (`game.cc:1380-1382`). No MOVIE_SIZE, no MAINMENU scaling; STATIC_SCREENS limited to SPLASH_SCRN_SIZE (`game.cc:1457-1458`).
- Interface bar bottom-centered (`interface.cc:320-323`). Custom widths need HR_IFACE_<width>.FRM (`customInterfaceBarInit`, `interface.cc:2482-2500`), silent fallback to 640. Side art HR_IFACELFT/RHT stretched (`interface.cc:2519-2545, 2607-2614`).
- IFACE_BAR_MODE (`interface.cc:260-261`) via screenGetVisibleHeight (`svga.cc:347-355`): world view = screen height − 100.
- **UI scaling verdict**: NO mechanism to enlarge UI/fonts. Only lever = SCALE_2X (integer, floor 640x480 internal). 11" iPad landscape 1194x834 points: native = tiny UI (~4.7 mm buttons); SCALE_2X needs 597x417 → **rejected**. Readable UI requires engine work (render-scale decoupling) or a lower internal res letterboxed. Biggest iPad-readability gap.

## 3. Audio (`src/audio_engine.cc`)

- `audioEngineInit()` :96-113 — desired 22050/S16/2ch/1024; SDL_OpenAudioDevice with SDL_AUDIO_ALLOW_ANY_CHANGE (:105); adapts via per-buffer SDL_AudioStream.
- 8 static sound buffers (:11), per-buffer stream resampler (:158), mixed in callback with SDL_MixAudioFormat (:47-94). Frame-by-frame conversion TODO (:70). Panning silently ignored (:255-257).
- Consumers: SFX/speech/music via `sound.cc:711`; MVE movie audio `movie_lib.cc:855`. ACM decoder `sound_decoder.cc` (soundDecoderInit :1141), wrapped `audio.cc:101`, `audio_file.cc:99`. soundInit(_detectDevices, 24, 0x8000, 0x8000, 22050) (`game_sound.cc:228`).
- Volume keys (`game_config.h:55-64`, defaults `game_config.cc:90-104`): [sound] initialize/sounds/music/speech=1, master/music/sndfx/speech_volume=22281 (0–32767), cache_size=448, music_path1/2="sound\music\" + CE auto-detect data\sound\music\*.acm rewrite (`game_config.cc:127-141`).
- **No iOS audio code**: no AVAudioSession/AVFoundation anywhere. Interruptions = SDL CoreAudio defaults. Pause/resume only via FOCUS_LOST/GAINED (`input.cc:945-953`) → SDL_PauseAudioDevice (`audio_engine.cc:123-135`). Mixer silences when !gProgramIsActive (:49-53).

## 4. App lifecycle

- Zero occurrences of SDL_APP_WILLENTERBACKGROUND/DIDENTERBACKGROUND/WILLENTERFOREGROUND/DIDENTERFOREGROUND/TERMINATING/LOWMEMORY, SDL_AddEventWatch, SDL_SetEventFilter, SDL_iPhoneSetAnimationCallback, SDL_iPhoneSetEventPump. **No iOS lifecycle handling.**
- Entry: main() in `win32.cc:28-73` (SDL_main wrapped; UIKit shim). SDL_Init(AUDIO|VIDEO|EVENTS) (:57), atexit(SDL_Quit), falloutMain().
- Main loop blocking while-loop: `mainLoop()` `main.cc:315-359`, FpsLimiter 60 FPS SDL_Delay (`fps_limiter.h:8`, `fps_limiter.cc:18-23`). No SDL_iPhoneSetAnimationCallback.
- On background: SDL UIKit delivers FOCUS_LOST on willResignActive → handler (`input.cc:950-953`) sets gProgramIsActive=false, pauses audio. Next inputGetInput() enters `_GNW95_lost_focus()` (`input.cc:1021-1028`): `while (!gProgramIsActive) { _GNW95_process_message(); SDL_Delay(125); }` — 8 Hz freeze loop. Incidentally avoids GPU-in-background kills in common case. Residual risks: (a) present paths that don't pump input first (palette fades) can race backgrounding; (b) **no save-on-background** — suspension kill = silent progress loss; (c) TERMINATING/LOWMEMORY ignored; (d) SDL_QUIT → exit(EXIT_SUCCESS) (`input.cc:956-958`) bypasses gameExit() — config-save-on-exit doesn't run.

## 5. Filesystem, data files, iOS paths

- CWD is everything. iOS: chdir(iOSGetDocumentsPath()) before SDL_Init (`win32.cc:39-43`); paths.mm returns NSDocumentDirectory (`paths.mm:8-33`). macOS: SDL_GetBasePath (`win32.cc:45-49`); Android: SDL_AndroidGetExternalStoragePath (:51-55). SDL_GetPrefPath never used.
- Expected files (relative to CWD): defaults `game_config.cc:61-64`: master_dat=master.dat, master_patches=data, critter_dat=critter.dat, critter_patches=data. Mounted in gameDbInit (`game.cc:1323-1385`): master.dat + data, critter.dat + data, patch000.dat…patch999.dat loop (:1372-1378, template overridable via sfall Misc.PatchFile), optional f2_res.dat (:1380-1382). dbOpen/xbaseOpen (`xfile.cc:~480-556`): DAT2 archive if dbaseOpen succeeds, else directory (chdir probe :539-540), else **creates** directory (:545-549). Lookup: most-recent xbase first, CWD fallback (`xfile.cc:71-138`).
- README iOS (`README.md:75-83`): sideload; run once (errors "Couldn't find/load text fonts" — `window.cc:1388-1392` — forcing sandbox into existence); Finder/iTunes File Sharing copy master.dat, critter.dat, patch000.dat, data/, lowercased.
- Info.plist: UIFileSharingEnabled=true (:33-34), LSSupportsOpeningDocumentsInPlace=true (:27-28) → Documents visible in Files app + Finder.

## 6. Case sensitivity

- iOS APFS data volume is case-sensitive; codebase handles explicitly:
  - `compat_resolve_path()` (`platform_compat.cc:313-365`): per-component opendir+readdir case-insensitive match rewrite. Invoked by compat_fopen/gzopen/mkdir/remove/rename/access (:203-373), preceded by compat_windows_path_to_native (:300-311) (backslash→slash). Cost: O(dir entries) per component per open.
  - Config paths normalized at startup: gameConfigResolvePath (`game_config.cc:186-193, 240-246`).
  - DAT2 lookups: case-insensitive bsearch, compat_stricmp (`dfile.cc:624-635`).
  - Pattern matching lowercases (`file_find.cc:29,44,73`, fpattern).
- Residual edge (README "keep lowercased"): config values must string-match real layout; bsearch presumes stricmp-consistent DAT index ordering (true for stock; pathological mod DATs could misorder).

## 7. Saves & config

- Files read: (1) fallout2.cfg (`game_config.h:8`; path = argv[0] dir else CWD, `game_config.cc:151-176`; on iOS = Documents; name overridable via sfall Misc.ConfigFile). (2) f2_res.ini (`svga.cc:109`, `game.cc:1457`; whitelisted for script ini access `sfall_ini.cc:18-21`). (3) ddraw.ini (`sfall_config.cc:10`, read :81, ~50 gameplay keys :26-68 — no display keys).
- f2_res.ini keys+defaults: [MAIN] SCR_WIDTH (→640), SCR_HEIGHT (→480), WINDOWED (→0), SCALE_2X (→0); [IFACE] IFACE_BAR_MODE (→false), IFACE_BAR_WIDTH (→-1→640), IFACE_BAR_SIDE_ART (→2), IFACE_BAR_SIDES_ORI (→false); [STATIC_SCREENS] SPLASH_SCRN_SIZE (→0). fallout2.cfg has NO resolution keys.
- Auto-generation: fallout2.cfg defaults seeded in memory (`game_config.cc:60-109`), tolerant merge (:180), **written on clean exit** via gameExit→settingsExit(true) (`game.cc:482`, `settings.cc:35-41`). Init failure (missing master.dat) → settingsExit(false), writes nothing. **f2_res.ini and ddraw.ini never auto-created.** iPad user must hand-author f2_res.ini via Files app to escape 640x480.
- Missing fallout2.cfg: runs fine on defaults.
- Saves: `"%s\\%s", _patches, "SAVEGAME"` (`loadsave.cc:1539,208,341`) → default **data/SAVEGAME/SLOT01..10/SAVE.DAT** (+ per-slot maps, .BAK). On iOS inside Documents → preserved across updates, deleted on uninstall, visible in Files. Quick/auto-save via sfall AutoQuickSave (`sfall_config.cc:60`).

## 8. Portability / UB

- 64-bit: interpreter reworked — ProgramValue separate pointerValue, uintptr_t compares (`interpreter.cc:935,944,1031,1040,1135,1394`; `interpreter_extra.cc:1497`); CE parallel pointer store for globals ("Sonora folks", `game.cc:119-120`). Benign int↔pointer smuggles in anim callbacks (`combat_ai.cc:3377`, `actions.cc:466,1507`).
- Endianness: fileReadInt32 unconditional swap (`db.cc:321-333`); DAT2 headers raw LE fread (`dfile.cc:75-137`) → assumes little-endian host (fine arm64).
- Threading: single-threaded + SDL audio callback (recursive_mutex per buffer). steady_clock timing (`platform_compat.cc:217-226`).
- zlib for gzipped saves/files (gzip sniffing `xfile.cc:140-152`).

## 9. Multiplayer

**None.** Zero networking code (only "socket" hits are prose comments in interface.cc about item slots).

## Cross-cutting implications

1. Resolution/DPI onboarding = #1 UX gap: no display query, no auto f2_res.ini, first run intentionally errors. Polished port: query display at boot, generate f2_res.ini, fix touch/letterbox mismatch (`touch.cc:102-103`).
2. UI readability: no scaling; SCALE_2X floor 640x480. Engine work needed for readable claims.
3. Lifecycle: add SDL_AddEventWatch for WILLENTERBACKGROUND (autosave + halt presents synchronously), handle TERMINATING/LOWMEMORY.
4. Audio: add AVAudioSession interruption/route handling.
5. Performance headroom fine: CPU 8→32 + full-frame upload trivial for A-series; palette-cycling full re-blits are the hot spot at native pixel resolutions.
