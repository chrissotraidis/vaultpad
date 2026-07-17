# Report 6: GitHub Ecosystem, Community, Interest, Names

All GitHub API data accessed 2026-07-17 via authenticated gh CLI.

## Key facts (TL;DR)

1. **Upstream alexbatalov/fallout2-ce is dormant** — last commit 2025-02-16, zero commits 2026. Maintainer active elsewhere (arcanum-ce, pushed 2026-05-26; SDL forks 2026-04-08). Pattern: RE a game, ship CE, move on. fallout1-ce (2,837 stars) also dormant (2025-01-15).
2. **Community continuation `fallout2-ce/fallout2-ce`** (org created 2024-05-07): **880 commits ahead, 0 behind**, pushed 2026-07-17 (same day as research). 92 stars, 342 merged PRs, 22 open; 15 commits merged in week of 2026-07-10→17. Top contributors: roginvs (412), mikeklaas (182), cambragol (101), phobos2077 (65), APAmk2 (35). README: fork of original "which is no longer getting regular updates". WASM build playable at fallout2-ce.github.io. Rolling `continious` [sic] pre-release only (re-published 2026-07-17) with fallout2-ce-ios.zip, DMG, APK, Linux arm64/armhf. Download counters reset each publish (~0, not a demand signal). v1.4.0 bump PR #348 closed unmerged 2026-04-02 — no versioned release yet.
3. **iPad work already in fork**: PR [#377](https://github.com/fallout2-ce/fallout2-ce/pull/377) (tectiv3, merged 2026-04-29) — "Makes fallout2-ce playable on iPad without a keyboard": 3-finger swipe-down = ESC; 3-finger long-press = hold Shift (highlight); 4-finger long-press = F6 quicksave; interface-bar taps inject keycodes directly (cursor stays put); iPad keeps trackpad mode in combat, touchscreen mode in UI screens; optional iOS quick-actions toolbar with 8 skill shortcuts (`src/platform/ios/quick_toolbar.cc`, `quick_toolbar_visible` cfg). README "Controls on iPad" section.
4. **Fork's open touch backlog**: [#398](https://github.com/fallout2-ce/fallout2-ce/issues/398) (2026-04-21, mikeklaas/tectiv3 punch list): alerts + save screens need touch mode; touch targets too small; item drag finicky; no depressed-button states; options sliders hard; character selector lacks touch mode; skilldex dismissal.
5. Known iOS pain points (all upstream issues): **no virtual keyboard invocation for barter** (#423, open 2024-10-10, comments through 2026-04-13 — confirmed NOT fixed in fork as of 2026-03-19 exchange); file import iTunes/Finder-only + **documents not appearing in Files app** (#343 closed 2024-01-16, #387 open, #280 open); **case-sensitivity failures** (`maps` vs `MAPS` save bug #393 closed/ #497 open; uppercase Steam files #236; music missing #234/#219); trackpad cursor complaints (#508 open 2026-01-17, #286, #266). **PR #304 "Use touchscreen as touchscreen" (roginvs) closed UNMERGED 2024-04-19** — direct-tap input, tablet-validated, died over phone-vs-tablet disagreement; commenters wanted config flag. Code exists and is directly reusable.
6. **No reports of the IPA failing outright on modern iPadOS 17/18** — friction reports only. #393 = running on iPadOS 17.5.1; #423 = iOS 18.
7. **Demand niche but real**: lifetime upstream IPA downloads ≈ **8,103** (v1.3.0: 5,717; v1.2.0: 2,386) vs Android ≈31.6k; fallout1-ce IPA ≈8,270 more. Press: iMore 2024-07-09 iPad angle ("A dream come true" r/iPadPro); Wololo (Vita); GBAtemp; NMA threads; MacSourcePorts hosts macOS build. **No Ars Technica coverage verifiable — do not cite.** MacRumors thread from ~2011 shows demand predates iPad 2.

## Repo health details

Upstream: created 2022-05-19; 2,364 stars, 187 forks; issues 119 open / 196 closed; PRs 16 open / 126 merged / 54 closed-unmerged; last merged PR #458 2025-02-15; open PRs back to 2022 (#202 TrueType, 2022-11-11). Last release v1.3.0 2024-04-21.

Commit cadence: 2022: 591, 2023: 209, 2024: 20, 2025: 59, 2026: 0 (Jan–Feb 2025 cleanup sprint then stop).

## Forks with iOS work

- **fallout2-ce/fallout2-ce** — the continuation (see above). Only fork with merged meaningful iOS improvements.
- **tectiv3/fallout2-ce** (0★, fork of the org, pushed 2026-05-08) — PR #377 author's fork with **unmerged iOS work**: "iOS: make actions menu sticky", "iOS: change touchscreen mode to always-on by default (disabled only in gameplay + worldmap)", "Refactor mouse input handling for iOS", **"iOS: validate cloud slot integrity before pulling saves" — iCloud-save experiment**. Worth contacting.
- **roginvs/fallout2-ce** (16★, 2026-02-25) — web/emscripten; PR #304 author.
- Platform ports (no iOS relevance): Northfear vita (79★), ryandeering switch (28★, 2026-05-21), isage vita (27★), MrHuu 3ds, jaca772 ps4 (2026-07-13), MrMilenko OG Xbox.
- Ruled out: powerje, JanSimek, cambragol forks (no unique iOS commits). `gh search repos "fallout2 ios"` nothing further.

## Related projects

- fallout1-ce: 2,837★, dormant 2025-01-15, IPA since v1.0.0, no community continuation org.
- Fallout: et tu (rotators/Fo1in2): 795★, extremely active (2026-07-16). Not yet F2CE-compatible.
- sfall: 428★, active daily (2026-07-17). x86 DLL, not portable to iOS; feature-parity reference.
- falltergeist: 887★, dead (2022-07-15).
- vault13 (pingw33n): Rust FO2 engine reimplementation, 181★, sporadic (2025-12-15). Prior art + name collision.
- fallout2-re: RE reference, 397★, purpose complete.

## Name check (2026-07-17)

Trademark context: Bethesda USPTO "Pip Boy" filing 2013; VAULT BOY registered (uspto.report/TM/86649770); Fallout/GECK Bethesda-controlled; "Wasteland" = inXile mark.

| Name | Collisions | TM adjacency | Risk |
|---|---|---|---|
| **VaultPad** | dormant Windows freeware encryptor (trustfm.net); tiny note-vault repos; no App Store app | "Vault" alone not a Bethesda mark | **Low** |
| WastelandPad | zero GitHub hits | inXile "Wasteland" | Low-moderate |
| Wasteland Touch | zero | same | Low-moderate |
| TouchVault | 3 small security repos | none | Low-moderate (password-manager semantics) |
| ChosenOne | toy repos | FO2 protagonist, not registered | Low (poor searchability) |
| Arroyo | **ArroyoSystems/arroyo 4,963★** | none | High collision — avoid |
| Vault13 | **pingw33n/vault13 — FO2 engine in same niche** | iconic location | High collision — avoid |
| Vault15 | negligible | location name | Low-moderate |
| PipPad | CalbeMaia/PipPad etc. | evokes Pip-Boy | Moderate-high — avoid |
| PadBoy | launchpad site | Pip-Boy/Game Boy echo | Moderate |
| GECKPad | zero | GECK = Bethesda editor | Moderate — avoid |
| HighwaymanApp | unrelated repos | FO2 car, generic word | Low |
| F2CE iPad | descriptor | reads as official F2CE | Low legal / moderate confusion |
| Fallout2 CE iPadOS | — | contains Fallout word mark | High for store/marketed use |
| "Fallout 2 CE Helper" | zero | contains Fallout; descriptive framing | Moderate-high |

Ranking: 1. VaultPad, 2. HighwaymanApp, 3. ChosenOne, 4. Vault15, 5. WastelandPad, 6. Wasteland Touch, 7. TouchVault, 8. "Fallout 2 CE Helper" (subtitle only), 9. F2CE iPad (coordinate with org), 10. PadBoy, 11. GECKPad, 12. PipPad, 13. Fallout2 CE iPadOS, 14. Vault13, 15. Arroyo.

## Bottom line

Fork **fallout2-ce/fallout2-ce** (not alexbatalov), rebase on tectiv3's merged+pending iOS work, differentiate on documented unsolved gaps: virtual-keyboard invocation (#423), Files-app/document-picker import (#343/#387/#280), automatic case-normalization (#236/#393/#497), touch-target scaling/mode consistency (#398), polished onboarding — every one a currently-open, user-reported pain point with no owner.
