# iPad touch lockup and command-bar audit

Date: 2026-07-21

## Scope

This audit covers the reported Modify → Cancel cursor drift, persistent Pan state, command-bar clarity and size, combat terminology, and Field Terminal hierarchy. The source images are the three physical-iPad screenshots supplied for this pass.

## Priorities

1. **P0 — input recovery:** no gesture or synthetic press may survive a modal transition. Returning from the character editor, Skilldex, or native settings must restore finger-aligned direct touch.
2. **P0 — no trapped Pan mode:** map panning is momentary while two fingers are down. There is no persistent Pan selection that can consume every later world tap.
3. **P1 — command clarity:** the compact bar uses full words, names the current action cost without the unexplained `AP` abbreviation, previews the alternate action (for example, `Kick / 4`), and spells out Settings.
4. **P1 — forgiving targets:** the full visible Print, Done, and Cancel labels in the character editor act as touch targets while the original art remains unchanged.
5. **P2 — terminal hierarchy:** the Field Terminal explains action points, target percentage, action cycling, and the contextual alternate action; help copy wraps instead of truncating.

## Evidence

- `01-toolbar-overweight.png`: the prior non-combat bar was visually dominant, duplicated a persistent Pan state, and used `VP` and `AP` without explanation.
- `02-field-terminal.png`: the prior terminal had good color direction but truncated the most important shortcut text and left the combat model unexplained.
- `03-control-lockup-combat.png`: the game continued animating while a persistent input mode consumed taps, leaving no reliable recovery path.
- `04-simulator-command-strip.png`: the corrected simulator build keeps the original HUD full-width, uses a shorter and darker command strip, and presents the current and alternate actions as `Punch / 3` and `Strong Kick` instead of `Use Item` and `Swap hand`.

## Simulator acceptance

- New Game -> Modify -> Cancel returns to direct touch with the cursor under the next touch.
- The persistent Pan mode no longer exists; two-finger drag is momentary and releases back to the prior command.
- The command strip synchronizes after the game initializes its actions, so its text agrees with Fallout's HUD.
- The alternate-action button previews the result of tapping it instead of exposing hand-slot terminology.
- Multi-touch feel and long-combat reliability still require the physical iPad pass; simulator automation cannot reproduce two independent fingers.

Screenshot inspection can establish hierarchy, labels, size, and visible state. It cannot establish physical touch latency, multi-touch comfort, VoiceOver behavior inside the bitmap game UI, or long-session stability; those remain device acceptance checks.
