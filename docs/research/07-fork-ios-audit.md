# Report 7: Fork audit — fallout2-ce/fallout2-ce iOS/iPad layer vs upstream

**Accessed 2026-07-17.** Fork HEAD: `aa439ef` (pushed 2026-07-17); upstream HEAD: `e97087b` (2025-02-16, dormant).

## Key facts

- **One iOS PR defines the whole delta**: PR **#377** "iOS/iPad: touch gestures, HUD tap-through, and quick-actions toolbar" by **tectiv3**, merged **2026-04-29 by mikeklaas** (+538/−45, 17 files). Everything `TARGET_OS_IOS`-guarded.
- **Gameplay world view is STILL trackpad-mode on iOS** — deliberately (`src/game_mouse.cc:1466-1472` forces `touch_set_touchscreen_mode(false)` on iOS). UI screens (dialog, inventory/barter, pipboy, loadsave, elevator, skilldex, automap, options, prefs, main menu, char editor/selector) are direct-touch.
- **No new UIKit code**: still exactly one `.mm` (`paths.mm`, byte-identical to upstream). No UIDocumentPicker, no iCloud/NSUbiquitous, no AVAudioSession, no SDL_APP_* lifecycle handling, no Files-app import flow (Android got `ImportActivity.java`; iOS did not).
- **Keyboard summoning unchanged**: same 3 `beginTextInput()` sites; **barter/move-items quantity dialog still has no keyboard** (`src/inventory.cc:6136` `inventoryQuantitySelect`).
- **No display auto-config, no safe-area handling**: resolution from `fallout2.cfg [screen] resolution_x/y` (default 640x480); README tells iPad users to hand-enter device logical points (`README.md:134`).
- **iOS artifact**: real IPA structure (`Payload/fallout2-ce.app`), **unsigned**, arm64, bundle id **still `com.alexbatalov.fallout2-ce`**, version 1.3.0, Xcode 15.4/iphoneos17.5 SDK on macos-14; rolling `continious` IPA is a **Debug** build. **ce.dat ships next to the IPA in the zip, NOT bundled inside the iOS .app** (bundling is macOS-only per `CMakeLists.txt:521,584-605`); missing ce.dat non-fatal (debugPrint only) but fork features needing it (e.g. `expand_barter_window`) silently degrade — user must copy ce.dat into Documents manually.
- **Fact-check**: upstream PR **#369** (case-sensitive fileFindFirst fix) **was merged upstream 2025-01-13** (`merged_at: 2025-01-13T15:05:14Z`); `compat_resolve_path(basePath)` present in `file_find.cc:33` in **both** trees. Fork adds no further case fixes; upstream #497 (can't save, iPhone, 2025-06-21) still open with no fork counterpart fix.
- **Plist quirk**: fork IPA `MinimumOSVersion 10.13` — the CMake `if(IOS)` at line 8 evaluates before the toolchain sets IOS in the release.yml toolchain path, leaking the macOS floor into the iOS plist (cosmetic).

## 1. iOS platform layer

Fork `src/platform/ios/`: `paths.h/.mm` identical to upstream; **new** `quick_toolbar.cc/h`. `os/ios/` byte-identical to upstream (Info.plist keeps UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace, UIRequiresFullScreen, landscape-only).

**quick_toolbar.cc**: 8 fixed skill buttons, 36x24 px (`quick_toolbar.cc:21-44`): SNK/LCK/STL/TRP/F-A/DOC/SCI/RPR → SKILLDEX_RC_* constants. Rendered as an engine window (`windowCreate(..., WINDOW_HIDDEN | WINDOW_TRANSPARENT)`, centered, `INTERFACE_BAR_HEIGHT + 24 + 10px` above bottom, `quick_toolbar.cc:118-129`); palette fills + fontDrawText (font 101). Tap path bypasses mouse pipeline: `quickToolbarHandleTap()` → `gameHandleSkilldexResult()` directly — no cursor move, no mouse events (`quick_toolbar.h:28-30`, `quick_toolbar.cc:202-222`). Guarded by `interfaceBarEnabled() || gameUiIsDisabled()`. Toggled by **`[ui] quick_toolbar_visible`** (default false; `settings.h:80`, `settings.cc:163`), applied `interface.cc:644-645`, shown/hidden with interface bar (`interface.cc:851,873`). Non-iOS: inline no-op stubs.

UIKit grep (fork src/ + os/ios/): UIDocumentPicker 0, NSUbiquit 0, UIKeyboard 0, AVAudioSession 0. beginTextInput sites: `dbox.cc:1119`, `character_editor.cc:1944`, `loadsave.cc:2650` — same three as upstream.

## 2. Touch input as implemented (PR #377)

- `src/touch.cc` +33 lines: runtime flags `gUseTouchscreenMode`/`gUsePanMode` with setters (`touch.cc:40-41,300-317`; `touch.h:35-38`). Touchscreen mode: every gesture-centroid update warps cursor — `mouseHideCursor(); _mouse_set_position(centroid); mouseShowCursor();` (`touch.cc:278-283`). **Runtime flags, not config — no config key for input mode.**
- `src/mouse.cc` `_mouse_info` (`mouse.cc:425-570`):
  - 3-finger pan down → ESC when `dy > screenGetHeight()/4` (`mouse.cc:448-458`).
  - 4-finger long-press → F6 quicksave (`mouse.cc:464-469`; long-press beats swipe because iPadOS intercepts multi-finger swipes).
  - 3-finger long-press → hold LShift via real SDL_PushEvent KEYDOWN/KEYUP so sfall `key_pressed()` sees it (`mouse.cc:472-493`).
  - **HUD tap-through** `handleHudTapThrough` (`mouse.cc:373-421`, iOS-only): tap inside `gInterfaceBarWindow` walks button list; 1-finger injects `leftMouseUpEventCode`, 2-finger `rightMouseUpEventCode` via enqueueInputEvent — keycode injection, cursor never moves. Taps on bare belt chrome consumed silently.
  - Quick-toolbar taps handled first, only when NOT in touchscreen mode (`mouse.cc:498-507`).
  - Regular taps: trackpad mode → click at cursor; absolute mode → `_mouse_set_position(gesture.x,y)` then click; 2-finger = right (`mouse.cc:515-528`).
  - Pan mode: only in inventory screens (`inventory.cc:2005-2006`/2053-2054) — 1-finger drag = wheel scroll coefficient 8 (vs 2 for 2-finger elsewhere) (`mouse.cc:549-561`).
- Touchscreen mode per-screen, hardcoded: character_selector.cc:152, automap.cc:334, game_dialog.cc:1025 (+2045/2055/2065), pipboy.cc:511, elevator.cc:352, inventory.cc:2005, character_editor.cc:812, loadsave.cc:499/1136 (load screens; save-normal = touch true), preferences.cc:1234, mainmenu.cc:600, skilldex.cc:119, options.cc:126; disabled on exit + worldmap.cc:3048.
- World view `game_mouse.cc:1465-1472`: iOS forces trackpad ("so tapping the screen doesn't teleport the cursor mid-combat"); Android uses direct-touch when MOVE cursor mode.
- Relative-vs-absolute mouse decided by fullscreen state: `mouseDeviceUsesRelativeMode()` ⇔ `screenIsFullscreen()` (`dinput.cc:45-70`, `svga.cc:344-348`).
- Config keys (all fork additions, `settings.cc:146-176`): `[screen]` resolution_x (640-7680), resolution_y (480-4320), windowed, scale (1-4); `[ui]` main_menu_scale_mode, in_game_menu_help, iface_bar_mode, iface_bar_width, iface_bar_side_art, iface_bar_sides_ori, splash_screen_size, movie_aspect_fit, edg_support, ignore_map_edges, quick_toolbar_visible, anim_speed, skip_opening_movies, display_karma_changes, display_bonus_damage, numbers_in_dialogue, dialog_border, auto_quick_save, enable_high_resolution_stencil, extend_ap_bar, expand_barter_window, inventory_columns. No touch/input-mode keys. mouse_sensitivity now clamped **0.25–2.5** (`mouse.h:31-32`).

## 3. Display/rendering

- f2_res.ini gone as runtime input: `_GNW95_init_mode_ex` reads `settings.screen.*` (`svga.cc:107-127`); one-time migrator `src/game_config_migration.cc` copies f2_res.ini MAIN/IFACE/MAPS/STATIC_SCREENS/MOVIES → fallout2.cfg [screen]/[ui] (trigger: [screen] resolution_x absent, `game_config_migration.cc:52-58`).
- **No display-size query** (0 hits SDL_GetDisplayBounds/CurrentDisplayMode/DesktopDisplayMode). First run on iPad = 640x480 fullscreen stretched. No safe-area handling.
- svga.cc additions: screenIsFullscreen(), mouseDeviceRefreshWindowMapping() + movieHandleRendererReset() on size change (`svga.cc:398-403`), movie SDL-texture overlay in renderPresent (`svga.cc:406-413`), palette-correct screenshots; `[ui] main_menu_scale_mode` aspect-fit main-menu scaling.

## 4. Case sensitivity / saves

- Upstream #369 fix in both trees (`file_find.cc:33`). Fork adds `compat_mkdir_recursive` (`platform_compat.cc:232-254`) used by gameDbInit to pre-create patches dir; `compat_resolve_path` unchanged (`platform_compat.cc:382-434`). MAPS\/SAVEGAME literals unchanged (`loadsave.cc:403,2041,2792-2953`; `map.cc:719,1560`). Fork issues #483/#173 (Mac/iPhone save transfer, 2026) closed without a case patch. Upstream #497 unresolved anywhere.

## 5. Build / CI / release

- CMakeLists: quick_toolbar sources (`:356-361`); bundle id unchanged (`:422,442,450`); IOS deployment target "12" (`:8-9`); IPA via install→Payload + CPACK ZIP ext ipa (`:699-706`). ce.dat bundling macOS-only (`:521,584-605`).
- Presets: `ios` configure (Xcode via darwin-base, CMAKE_SYSTEM_NAME=iOS, `:135-142`), ios-debug/ios-release (`:262-271`).
- Workflows: adds reusable-build-ce-dat.yml, ci-build-web.yml, auto-format.yml. iOS on **macos-14** (Xcode 15.4; artifact DTXcode 1540, iphoneos17.5). `ci-build.yml:141-189`: preset ios → ios-debug → cpack -C Debug → zip IPA + sibling ce.dat → `fallout2-ce-ios.zip`. Every push to main deletes/recreates `continious` prerelease (`ci-build.yml:458-516`). `release.yml:80-138`: RelWithDebInfo + ios.toolchain.cmake PLATFORM=OS64, CODE_SIGN_IDENTITY='' for tags (none published by fork; v1.x tags inherited).
- Artifact (continious/fallout2-ce-ios.zip, 5.65 MB, published 2026-07-17T07:26): IPA + ce.dat (283 KB). codesign: unsigned. Binary arm64 8.27 MB Debug. Bundle id com.alexbatalov.fallout2-ce, version 1.3.0, UIDeviceFamily [1,2], MinimumOSVersion 10.13 (leak, cosmetic).
- gameDbInit (`game.cc:1331-1456`): load order master_patches > critter_patches > mods > patchXXX.dat > ce.dat > f2_res.dat > critter.dat > master.dat. TryLoadBaseCEMod(): "ce.dat" in CWD (iOS: Documents), then macOS-only bundle fallback (`game.cc:1340-1349`). Missing → debugPrint only, silent degradation.

## 6. README (fork, `README.md:74-96`)

iOS: download IPA, sideload via AltStore/Sideloadly; run once ("Couldn't find/load text fonts" exposes File Sharing); Finder/iTunes copy master.dat, critter.dat, patch000.dat, **ce.dat**, data/ — lowercased.

Controls on iPad: 1-finger tap = left click, hold = left held; 2-finger tap = right click (cycles walk/attack cursor); 1-finger drag = scroll map/windows; 2-finger drag = mouse wheel; 3-finger swipe down = ESC; 4-finger long-press = F6 quicksave; 3-finger long-press = hold Shift (highlight objects); HUD taps act as direct touches; Bluetooth keyboard for everything else.

`README.md:112-114`: f2_res.ini→fallout2.cfg auto-migration; `README.md:134`: iPad points guidance. No docs/ folder; CONTRIBUTING has no iOS build section.

## 7. Governance

- Org fallout2-ce: 92 stars, 14 forks, 64 open issues, pushed 2026-07-17. Public member: APAmk2. Active mergers: mikeklaas (#377, #533, sfall PRs), jirik2077 (#557, #550). roginvs early (fork PR #25, 2025-01-13). Contributors: alexbatalov(796 inherited)/roginvs(412)/mikeklaas(182)/cambragol(101)/phobos2077(65).
- `continious` recreated per push; 14+ PRs merged 2026-07-10→17.
- iOS PRs merged 2026: exactly one (#377, outside contribution accepted in 2 weeks). iOS not a maintainer focus.
- Open iOS issues: **#398** (2026-04-21) wishlist: alerts + save screen touch-mode, "maybe touch screen mode should be always on" except world/worldmap, touch targets too small, drag finicky (tap-to-pick-up/tap-to-drop), no pressed states.

## 8. Delta table: upstream pain points in the fork

| Pain point | Fork status | Evidence |
|---|---|---|
| No Files-app import UX | **STILL OPEN** (Android got ImportActivity; iOS didn't) | README.md:78-82; 0 UIKit hits |
| No display auto-config | **STILL OPEN** (cleaner config, still manual) | svga.cc:107-127; settings.h:31-36 |
| No barter-quantity keyboard | **STILL OPEN** | inventory.cc:6136-6301 |
| Trackpad-only gameplay | **PARTIALLY FIXED** — UI screens direct-touch, HUD tap-through, quick toolbar, 3/4-finger gestures; world view deliberately trackpad | PR #377; mouse.cc:373-570 |
| Case-sensitivity bugs | **INHERITED FIX ONLY** (#369 merged upstream 2025-01-13; both trees); #497-class complaints unresolved | file_find.cc:33 |
| No lifecycle handling | **STILL OPEN** | 0 hits |
| No AVAudioSession | **STILL OPEN** | 0 hits |
| ce.dat onboarding | **NEW FRICTION** — beside IPA, not bundled; silent degradation | CMakeLists.txt:521; game.cc:1331-1356 |
| Distribution | **UNCHANGED** — unsigned Debug IPA per merge; bundle id unchanged | codesign; ci-build.yml:163-189 |

**Bottom line**: fork's iOS delta = one well-engineered input PR + config consolidation. Makes iPad playable without a keyboard; touches nothing structural. Every product-grade gap remains open; #398 is the maintainers' own agreeing backlog. Maintainers merge weekly; accepted the one outside iOS PR in 2 weeks.
