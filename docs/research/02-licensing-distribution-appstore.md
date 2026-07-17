# Report 2: Licensing, Copyright, Trademark, App Store, Distribution

**Access date for all sources: 2026-07-17.** Not legal advice.

## A. Sustainable Use License (SUL) compliance

- LICENSE.md = **Sustainable Use License, Version 1.0** (n8n fair-code license, adopted verbatim). NOT OSI-approved; source-available/fair-code. README.md line 119 confirms.
- Grant (verbatim): "The licensor grants you a non-exclusive, royalty-free, worldwide, non-sublicensable, non-transferable license to use, copy, distribute, make available, and prepare derivative works of the software, in each case subject to the limitations below."
- Limitations (verbatim): "You may use or modify the software only for your own internal business purposes or for non-commercial or personal use. You may distribute the software or provide it to others only if you do so free of charge for non-commercial purposes. You may not alter, remove, or obscure any licensing, copyright, or other notices of the licensor in the software. Any use of the licensor's trademarks is subject to applicable law."
- Notices: recipients must get a copy of the terms; modified copies need a prominent modification notice.
- Termination: auto-terminate on violation; 30-day cure window; second violation permanent.

| Question | Answer |
|---|---|
| Commercial use? | **No** for distribution/products (no paid app, ads, IAP). |
| Free distribution of modified builds? | **Yes, explicitly** — "free of charge for non-commercial purposes" + modification notice + retain notices. |
| Source disclosure required? | **No** (no copyleft). |
| Same license for derivatives? | Effectively yes for distribution — non-sublicensable; shipped whole travels under SUL. |

Channel permissibility: (a) free GitHub releases of modified IPA — clearly permitted (licensor does exactly this); (b) free App Store — very likely permitted, untested (no SUL app store precedent found; $99/yr is paid to Apple, not charged to recipients); mitigation: email Batalov for written OK; (c) TestFlight — permitted; (d) AltStore/SideStore — permitted (upstream README recommends them).

Compliance checklist: ship LICENSE.md in bundle+repo; prominent "modified version of Fallout 2 Community Edition" notice (About + README); zero monetization; license screen showing terms; never remove Batalov's notices. Avoid donation prompts inside the app; GitHub Sponsors on repo is safer.

Third-party: SDL2 (zlib license), zlib (zlib), fpattern (MIT) — all permissive, no conflicts; standard acknowledgements screen.

README on game data (verbatim): "You must own the game to play. Purchase your copy on GOG, Epic Games or Steam."

## B. Copyright

- master.dat/critter.dat/patch000.dat/data/, all art/audio/text = Interplay→Bethesda/ZeniMax (Microsoft) copyright; actively sold on Steam/GOG/Epic — zero abandonware ambiguity. Never distributable; even store-listing screenshots of game art are a flag vector.
- **No Fallout 2 demo exists** (Fallout 1 had one, FO1-engine data, promotional license — unusable both ways). No freely redistributable data set for fallout2-ce.
- Data-less launch must be 100% original custom art (no Vault Boy, no trade dress). The one documented ZeniMax GitHub DMCA (2020-04-07) was Vault Boy Telegram stickers.
- Provenance tail risk: fallout2-ce descends from alexbatalov/fallout2-re — openly reverse-engineered from the original binary, not clean-room. Batalov's authority to license rests on untested fair-use position. If ZeniMax moved against upstream, all forks fall. 4 years of public releases with no action = tolerance, not immunity.

## C. Trademark

- "Fallout" is a ZeniMax/Bethesda (Microsoft) registered trademark.
- Enforcement record: **no action ever against fallout2-ce/fallout1-ce/fallout2-re** (searched full github/dmca repo: only ZeniMax notice = 2020-04-07 Vault Boy stickers). Vita fork and Fallout: et tu also untouched.
- **Fortress Fallout (2015)**: ZeniMax C&D'd an unrelated mobile game over the *name* — key precedent: they police "Fallout" in product names, especially mobile ([Kotaku](https://kotaku.com/fallout-publisher-sends-legal-threats-to-game-with-fall-1686111272)).
- **Capital Wasteland (2018)**: fan remake self-cancelled over *voice audio reuse*; sister project continued by re-recording — practical red line is asset redistribution, not engine work.
- Naming: repo "fallout2-ipados" = elevated risk (Fortress Fallout pattern). Neutral name (VaultPad) + descriptive mention = low risk (nominative fair use). Upstream sets `MACOSX_BUNDLE_DISPLAY_NAME "Fallout 2"` (CMakeLists.txt:335) — C&D magnet and App Store disqualifier (5.2.1, 4.1(c)); change to neutral display name.
- Disclaimer formula: "VaultPad is an unofficial, free, open-source engine reimplementation. Not affiliated with, endorsed, or sponsored by Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc. Contains no game content; a legally purchased copy of the original game is required."

## D. App Store feasibility (as of 2026-07-17)

- Guideline 4.7: retro game console **and PC emulator** apps can offer downloads (console added Apr 2024; PC emulator added Aug 2024 post-iDOS). Sub-rules 4.7.1–4.7.5 written for stores-within-apps.
- 2.5.2 self-contained code rule is in formal tension with running game script bytecode from user DATs — but **ScummVM (identical architecture) has been approved and listed since late 2023** (apps.apple.com id6446184412) — strongest positive precedent.
- 4.1 copycats + 5.2.1 IP: no third-party trademarks in name/icon/metadata; reviewers demand rights documentation when they perceive third-party IP.
- Precedents table: Delta (approved Apr 2024, Nintendo no action, Adobe logo threat only; predecessor GBA4iOS DMCA'd for linking to ROM sites — don't link to data downloads); iGBA (removed for 4.3 spam + 5.2 developer-vs-developer copying); PPSSPP/RetroArch (approved May 2024, no JIT — F2CE needs no JIT); iDOS 3 (rejected as "not a console", approved Aug 2024 after rule change — expect category semantics arguments); UTM SE (rejected then approved); Battle for Wesnoth (GPL, on store via SPI); official Fallout mobile = only Fallout Shelter, no official FO1/FO2 port exists.
- Probability: with "Fallout 2" branding **<5%**. Neutral brand, original art, no mark in metadata: **~50–65% first attempt, ~70–80% eventual** (iDOS/UTM persistence pattern; cite ScummVM in Review Notes). Post-approval removal on rights-holder complaint is a real, unquantifiable risk (iGBA same-week removal) — treat App Store as revocable.
- Rejection vectors ranked: (1) 5.2.1 mark spotted anywhere; (2) 4.7-scope/2.5.2 category argument; (3) 4.3(b) minimum functionality (empty shell without data — counter with polished onboarding); (4) post-approval complaint.

## E. Sideloading landscape (mid-2026)

| Channel | Status | Expiry/limits | Difficulty | Notes |
|---|---|---|---|---|
| Xcode free Apple ID | works | 7-day resign, 3 apps | High (Mac needed) | mirrors upstream "build from source" |
| Paid dev ad-hoc | works | 1-yr certs, 100 devices | Medium | fine under SUL if free |
| AltStore Classic | current; v2.3 beta on-device sideloading (iOS 17.4+) | 7-day refresh, 3-app | Medium-low | upstream's recommended channel |
| SideStore | active; +LiveContainer bypasses 3-app cap; works through iOS 26 | 7-day on-device refresh | Medium-low | |
| Sideloadly | active | 7d free / 1yr paid | Medium | named in upstream README |
| TrollStore | **dead for modern iPads** (iOS 14.0–16.6.1/17.0 only; CoreTrust patched 17.0.1; 17.6/18 mitigations) | permanent on old versions | Low | don't build on it |
| TestFlight | feasible | 90-day builds, 10k testers, Beta App Review | Very low | policy-fragile perpetual beta |
| AltStore PAL (EU+JP+BR) | free for users (Epic MegaGrant); CTF replaced by Core Technology Commission (free app owes ~nothing); Japan Dec 2025, Brazil Jun 2026 | no expiry; Apple notarization only | Low (region-limited) | best official no-review channel; Delta's home |
| EU Web Distribution | **not feasible**: needs 2+ yrs ADP, EU entity, >1M EU installs/yr | — | — | for large devs only |

Recommended strategy: (1) GitHub Releases IPA + AltStore/SideStore source JSON day one; (2) TestFlight parallel with neutral branding; (3) AltStore PAL for EU/JP/BR; (4) App Store attempt with strict hygiene, never a dependency; (5) email Batalov for courtesy acknowledgment before wide distribution.

## F. License–App Store compatibility

- VLC pulled Jan 2011 (GPLv2 vs App Store terms), returned 2013 after LGPL/MPL relicense. Wesnoth survives because copyright holders consent. GPL App Store problems = hostile enforcement, not automatic illegality.
- SUL is structurally easier than GPL: no anti-DRM clause, no "no further restrictions", no source-conveyance duty. Free $0 app + custom EULA/license screen satisfies it. No SUL App Store precedent either way — VaultPad would be first; only party with standing = Batalov.

## Bottom line

License green (free-only + notices); copyright: engine clean, zero Fallout assets ever, no demo escape hatch, RE-provenance tail risk; trademark: neutral name mandatory for App Store, strongly advised everywhere; App Store ~50–65%/70–80% with hygiene, revocable; distribution: GitHub+AltStore/SideStore base, PAL for EU/JP/BR, TestFlight accelerant, TrollStore dead.
