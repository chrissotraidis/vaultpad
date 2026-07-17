# Report 3: Input — touch, mouse, trackpad, keyboard, text entry

All paths relative to fallout2-ce repo root. Source audit at HEAD e97087b.

## Key facts (TL;DR)

1. **Touch is a virtual trackpad, not direct touch.** Taps click at the *current cursor position*, not at the tap location (`_mouse_simulate_input(0, 0, …)` — `src/mouse.cc:392`). Pans move the cursor by deltas. Absolute touch coordinates are computed in `touch.cc` but only ever used to derive deltas.
2. **Gesture map:** 1-finger tap = left click; 2-finger tap = right click; 1-finger pan = cursor move; 2-finger pan = mouse wheel; 1-finger long-press (500 ms) = left-button hold (enables drag); 2-finger long-press = right-button hold.
3. **Touch handling is compiled on every platform** (no `#ifdef` in `touch.cc` or the event pump). Only the SDL hints disabling mouse↔touch synthesis are iOS/Android-gated (`src/win32.cc:39-55`).
4. **Mouse is strictly relative**: `SDL_SetRelativeMouseMode(SDL_TRUE)` at init (`src/dinput.cc:96`), position via `SDL_GetRelativeMouseState` (`src/dinput.cc:56`); engine keeps its own cursor position and draws its own 8-bit cursor sprite. No absolute-position path exists anywhere.
5. **Text entry works on touch-only iPad — with caveats.** `SDL_StartTextInput()`/`SDL_StopTextInput()` wrapped by `beginTextInput()`/`endTextInput()` (`src/input.cc:1030-1038`), called in exactly 3 places: character naming (`character_editor.cc:1936`), save-slot naming (`loadsave.cc:2324`), file dialog (`dbox.cc:1118`). SDL iOS shows on-screen keyboard on SDL_StartTextInput and synthesizes scancode key events (engine never reads SDL_TEXTINPUT). The barter/move-items **quantity dialog does NOT call `beginTextInput()`** (`inventory.cc:5590-5719`) — typed quantities need hardware keyboard; +/- buttons still work.
6. **No gamepad support at all** — zero SDL_GameController/SDL_Joystick code in src/.
7. **Vendored SDL 2.26.1** (`third_party/sdl2/CMakeLists.txt:16`) — post-dates SDL 2.24 iPadOS pointer (GCMouse) improvements. iOS min target 12; GCMouse/GCKeyboard need iOS 14+ at runtime.
8. **Only input tunable:** `[preferences] mouse_sensitivity` (1.0–2.5, default 1.0), applied **only to physical mouse deltas, not touch pan deltas** (`src/mouse.cc:453-455`). No touch config keys exist.

## 1. Touch model (`src/touch.cc`, `src/touch.h`)

- `_GNW95_process_message()` (`src/input.cc:904`) routes SDL_FINGERDOWN/MOTION/UP to touch_handle_start/move/end (`input.cc:920-928`), calls `touch_process_gesture()` once per pump (`input.cc:962`).
- Up to MAX_TOUCHES 10 fingers (`touch.cc:14,35`). Coordinates converted from SDL normalized [0..1] to game-logical pixels: `event->x * screenGetWidth()` (`touch.cc:102-103`); SDL letterbox-scales via SDL_RenderSetLogicalSize (`svga.cc:364`). SDL2 does NOT letterbox-correct finger events (only mouse) — harmless since only deltas used, but delta scale off by letterbox factor when aspect differs.
- iOS quirk handled: finger IDs are UITouch pointers that get reused; touch_handle_start re-finds existing slot (`touch.cc:87-95`).

### Gesture recognizer (`touch_process_gesture`, `touch.cc:134-276`)
Thresholds (`touch.cc:16-18`): TAP_MAXIMUM_DURATION 75 (multi-finger stagger, not press length), PAN_MINIMUM_MOVEMENT 4 px, LONG_PRESS_MINIMUM_DURATION 500 ms.
- Tap (`touch.cc:224-252`): all fingers lifted, centroid <4 px moved, starts/ends within 75 ms of each other. Single-finger press up to ~500 ms still a tap.
- Pan (`touch.cc:253-265`): centroid ≥4 px while down → kPan/kBegan; kChanged per frame; lift/add finger → kEnded.
- Long-press (`touch.cc:266-273`): stationary ≥500 ms → kLongPress/kBegan, then kChanged (deltas allowed — enables drag) until release.
- Events queued in `static std::stack<Gesture> gestureEventsQueue` (`touch.cc:37`), popped LIFO in touch_get_gesture (`touch.cc:278-288`). **LIFO not FIFO — latent ordering bug** (kEnded may process before preceding kChanged).

### Gesture → synthetic mouse (`_mouse_info`, `src/mouse.cc:370-430`)
Called every poll (`_process_bk`, `input.cc:190`; `gameMouseRefresh`, `game_mouse.cc:500`). Pops ONE gesture per call; if consumed, returns early and skips physical mouse read that tick (`mouse.cc:429`).
- kTap: 1 finger → `_mouse_simulate_input(0, 0, MOUSE_STATE_LEFT_BUTTON_DOWN)` (`mouse.cc:392`); 2 fingers → RIGHT (`mouse.cc:394`). **Tap location discarded.** Button-up synthesized next poll.
- kLongPress (`mouse.cc:404-409`): 1-finger = left held + move (drag); 2-finger = right held.
- kPan (`mouse.cc:410-421`): 1-finger = cursor move; 2-finger = wheel: `gMouseWheelX=(prevx-x)/2; gMouseWheelY=(y-prevy)/2` (halved, natural direction), sets MOUSE_EVENT_WHEEL.
- `_mouse_simulate_input` (`mouse.cc:470`) = single injection point shared with real mouse: updates gMouseCursorX/Y, clips (`_mouse_clip`, `mouse.cc:615`), redraws cursor, derives MOUSE_EVENT_* bits (REPEAT re-fired every BUTTON_REPEAT_TIME 250 ms — `mouse.h:29`, `mouse.cc:505-538`).

### Platform enablement
Touch live everywhere; only gating = hints in `src/win32.cc:39-42` (iOS) / `:51-54` (Android): SDL_HINT_MOUSE_TOUCH_EVENTS=0, SDL_HINT_TOUCH_MOUSE_EVENTS=0 — engine recognizer is sole touch path; mouse never triggers gestures.

## 2. Mouse (`src/mouse.cc`, `src/dinput.cc`)

- Relative only: `SDL_SetRelativeMouseMode(SDL_TRUE)` (`dinput.cc:94-97`); poll via SDL_GetRelativeMouseState reading only LEFT/RIGHT buttons (`dinput.cc:46-66`). Deltas scaled by gMouseSensitivity (`mouse.cc:453-455`). No absolute path, no SDL_GetMouseState, no SDL_WarpMouse.
- Cursor fully engine-drawn; OS cursor hidden (`SDL_ShowCursor(SDL_DISABLE)`, `win32.cc:63`; re-enabled around SDL message boxes, `window_manager.cc:1337-1348`). Default 8×8 arrow `gMouseDefaultCursor` (`mouse.cc:28-39`), FRM frames via mouseSetFrame (`mouse.cc:188`) — dragged inventory item becomes the cursor (`inventory.cc:2363`). Game cursors in `game_mouse.h:40-68`, set by gameMouseSetCursor.
- Right-click cycles cursor modes: `_gmouse_handle_event` (`game_mouse.cc:896`), gameMouseCycleMode (`game_mouse.cc:920-925, 1422-1440`) MOVE → ARROW → CROSSHAIR (CROSSHAIR skipped out of combat/without weapon). Keyboard M does same (`game.cc:613-615`).
- Scroll wheel: SDL_MOUSEWHEEL accumulated in handleMouseEvent (`dinput.cc:115-124`), surfaced as MOUSE_EVENT_WHEEL + mouseGetWheel (`mouse.cc:460-466, 702-706`). Consumers: map scroll (`game.cc:495-514`), worldmap (`worldmap.cc:3254-3265`), inventory/barter/loot (`inventory.cc:684, 2736, 4401, 5267`), lists via convertMouseWheelToArrowKey → synthetic arrows (`mouse.cc:708-723`; loadsave.cc, dbox.cc:1136, game_dialog.cc:1884).
- Middle-click unsupported (2-entry buttons array).

## 3. Keyboard & text entry (`src/kb.cc`, `src/input.cc`)

- SDL_KEYDOWN/UP → `_GNW95_process_key` (`input.cc:996-1018`) → QWERTY normalization via gNormalizedQwertyKeys (`input.cc:568-895`) → `_kb_simulate_key` (`kb.cc:208`), 64-entry ring buffer, software key repeat (80 ms rate / 500 ms delay, `input.cc:47-50, 964-983`).
- ASCII via table lookup, not SDL text events: `_kb_next_ascii_English_US` (`kb.cc:318`); text widgets accept space..'z' (`kb.h:329-330`). **SDL_TEXTINPUT never handled** (only flush bound in keyboardDeviceReset, `dinput.cc:83`). Only US-QWERTY-reachable chars typeable; no IME/international input.
- On-screen iOS keyboard: beginTextInput()/endTextInput() (`input.cc:1030-1038`) call sites exactly three: `character_editor.cc:1936/2001` (_get_input_str, char naming), `loadsave.cc:2324/2394` (_get_input_str2, save-slot naming), `dbox.cc:1118/1382` (_fileDialog). These plausibly work touch-only. Quantity dialog (`inventory.cc:5706-5719`, KEY_0..KEY_9) has no beginTextInput → no keyboard. All in-game shortcuts (I/P/C/S/N/M/B, 0-9 dialogue, A, Space/Enter) unreachable without hardware keys.

## 4. Map edge-scrolling × touch cursor

- Every frame gameMouseRefresh → gameMouseHandleScrolling (`game_mouse.cc:2334-2417`): cursor at screen bounds → mapScroll + scroll-arrow cursor. `_gmouse_is_scrolling` (`game_mouse.cc:452-487`); gameHandleKey swallows events during scroll (`game.cc:544-546`).
- `_mouse_clip` pins cursor to screen rect → **1-finger pan reaching edge parks cursor on edge and map free-scrolls until panned back inward**. `_gmouse_click_to_scroll` hardcoded 0 (`game_mouse.cc:54`). 2-finger pan (wheel) map scroll is the friendlier alternative already wired (`game.cc:495-514`).

## 5. Interaction-by-interaction table

Scheme: pan cursor into place, then tap (left) / 2-finger tap (right) / long-press-drag.

| Interaction | How today | Works? | Pain points |
|---|---|---|---|
| Walking | Pan to tile, tap → `_dude_move` (`game_mouse.cc:927-949`) | Yes | Two-step; tap-anywhere clicks at cursor |
| Running | `[preferences] running=1` or Shift+click (`game_mouse.cc:936-946`) | Yes | Shift needs HW keyboard |
| Attacking | 2-finger tap cycles to CROSSHAIR, position, tap → `_combat_attack_this` (`game_mouse.cc:1000-1017`) | Yes | Mode cycling undiscoverable; mis-taps cycle cursor |
| Aimed shots | Right-click on interface-bar item button (`buttonSetRightMouseCallbacks(gSingleAttackButton, -1, KEY_LOWERCASE_N, …)` `interface.cc:511`) → interfaceCycleItemAction (`interface.cc:1211`) → attack opens body-part picker | Marginal | Park cursor over button then 2-finger tap, or 'N' key; undiscoverable |
| Skills/Skilldex | Skilldex button (22×21 px, `interface.cc:406`) or 'S'; tap target (`game_mouse.cc:1051-1064`) | Yes | Tiny button |
| Opening doors | ARROW tap on scenery → `_action_use_an_object` (`game_mouse.cc:981-989`) | Yes | Mode-cycle friction |
| Talking to NPCs | ARROW tap critter → actionTalk (`game_mouse.cc:968-975`) | Yes | Same |
| Looting | ARROW tap container/body → `_action_loot_container` (`game_mouse.cc:977`) | Yes | See drag |
| Action menu (Look/Use/Talk…) | Hold left on object (REPEAT bit, `game_mouse.cc:1067`), vertical cursor movement selects (`game_mouse.cc:1135-1159`), release activates | Marginal | long-press 500ms → vertical drag → lift; three precise phases |
| Dragging inventory | `_inven_pickup` (`inventory.cc:2268`), item becomes cursor (`inventory.cc:2363`), loop while LEFT_BUTTON_REPEAT (`inventory.cc:2371-2379`) | Yes via long-press-drag | Hold 500 ms without moving 4 px, then drag; error-prone |
| Equipping | Drag to hand/armor slot | Yes | Same |
| Reloading | Cycle item action to RELOAD (right-click item button / 'N', `interface.cc:1248-1251`) or drag ammo onto weapon | Marginal | Two weakest gestures |
| Pip-Boy | Button 41×19 px (`interface.cc:454`) or 'P'; inside: clickable text lists, no wheel in pipboy.cc | Yes | Small targets |
| Scrolling long lists | Wheel = 2-finger pan; save/load converts wheel→arrows; inventory wheel (`inventory.cc:684`) + arrow buttons | Yes | Halved deltas slow |
| Dialogue selection | Tap option text; 1-9 hotkeys need keyboard; review pane wheel (`game_dialog.cc:1884`) | Yes | Font-height targets |
| Barter | Drag between 4 panes; quantity dialog setupMoveItems (`inventory.cc:5590+`): +/- with hold-autorepeat (`inventory.cc:5632-5653`), typed digits (`inventory.cc:5706-5719`) | Marginal | Heavy drag; **no on-screen keyboard for typed quantities** |
| Character creation | Stat +/- standard clicks; name entry has beginTextInput (`character_editor.cc:1936`) | Yes | Small tag-skill rows |
| Save/load naming | _get_input_str2 beginTextInput (`loadsave.cc:2324`) | Yes | Keyboard covers ~half the view; no scroll-into-view |
| World map travel | Down near hotspot arms, up within 5 px enters (`worldmap.cc:3124-3138`); click empty map = travel; green triangles = buttons | Yes | Small targets |
| Car | Auto on travel (`worldmap.cc:3163-3170`); fueling = drag fuel cell to trunk | Yes | Depends on drag |
| Small interface buttons | END TURN 38×22 (`interface.cc:1903`), END COMBAT 38×22 (`interface.cc:1955`), inventory 32×21 (`interface.cc:360`), skilldex 22×21, map 41×19, options 34×34; END TURN=Space, END COMBAT=Return | Yes | ~5-7 mm targets; slow |

## 6. Gamepad

None. No SDL_GameController/SDL_Joystick in src/; SDL_Init requests AUDIO|VIDEO|EVENTS only (`win32.cc:57`). Would be built from scratch.

## 7. Pointer devices on iPadOS

- SDL 2.26.1 includes 2.24+ iPadOS GCMouse pointer improvements; GCMouse/GCKeyboard need iOS 14+ runtime.
- Engine runs permanently in relative mouse mode — on iPadOS hides system pointer, delivers raw deltas; engine cursor authoritative. Magic Keyboard trackpad / BT mouse should behave like desktop. Caveats: (a) only tuning is 1.0–2.5 sensitivity (can't go below 1.0, `mouse.cc:671-676`); (b) if relative mode fails, UIKit pointer visible and desynced; (c) trackpad 2-finger scroll arrives as SDL_MOUSEWHEEL and works (`dinput.cc:120-123`).
- All SDL_SetHint calls: `svga.cc:176` SDL_HINT_RENDER_DRIVER="opengl" (questionable on iOS); `win32.cc:40/52` MOUSE_TOUCH_EVENTS=0; `win32.cc:41/53` TOUCH_MOUSE_EVENTS=0.

## 8. Input config surface

- fallout2.cfg (defaults in gameConfigInit, `src/game_config.cc:60-113`): `[preferences] mouse_sensitivity` 1.0 (slider 1.0–2.5, `preferences.cc:389`, applied `preferences.cc:558,719`, physical mouse only); `[preferences] running` 0; `[system] scroll_lock` 0; `[system] interrupt_walk` 1; display/speed prefs: combat_speed 0, player_speed 0, text_base_delay 3.5, text_line_delay 1.4, brightness 1.0 (1.0–1.18), target_highlight 2, item_highlight 1.
- f2_res.ini (read `svga.cc:107-143`, `game.cc:1457`): [MAIN] SCR_WIDTH, SCR_HEIGHT, WINDOWED, SCALE_2X (rejected if <640×480), [IFACE] IFACE_BAR_MODE/WIDTH/SIDE_ART/SIDES_ORI, [STATIC_SCREENS] SPLASH_SCRN_SIZE.
- ddraw.ini (sfall): no input keys; cursor-art overrides [Misc] skill FRMs (`game_mouse.cc:2450-2459`), TownMapHotkeysFix (`sfall_config.h:69`).
- **No toggle exists for touch behavior, gesture thresholds, tap-vs-direct mode, or on-screen controls.** Gesture constants compile-time; touch deltas bypass sensitivity slider.

## Highest-leverage gaps for polished iPadOS

1. No direct-touch mode — kTap discards coordinates (`mouse.cc:392-394`); adding `_mouse_set_position(gesture.x, gesture.y)` before the click is trivial (API exists, `mouse.cc:605`).
2. Mode/aimed-shot discoverability: critical actions behind right-click (2-finger tap) and right-click on one specific button (`interface.cc:511`).
3. Quantity dialog + future text fields lack beginTextInput; keyboard shortcuts have no touch equivalents.
4. Edge-scroll + clipped cursor = runaway map scroll; gestureEventsQueue LIFO bug; touch deltas unscaled by sensitivity; no gamepad path.
