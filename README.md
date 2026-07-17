# VaultPad

**Feasibility study + complete build blueprint for a polished, iPad-first Fallout 2 experience, powered by Fallout 2 Community Edition.**

> Status: research & PRD complete (2026-07-17). Implementation not started. This repository currently contains the planning documents; the [PRD](docs/PRD.md) defines the product repo this becomes.

## Verdict (TL;DR)

**Strong go — as an iPad *productization* project, not an engine port.** The engine already builds for iOS, ships an unsigned IPA people sideload onto iPads today, and contains a working touch layer. What's missing is the product: native game-data import through the Files app, automatic resolution configuration, hybrid direct-touch controls, on-screen keyboard everywhere it's needed, background autosave, and a reproducible clone→sign→Run developer experience. Every one of those gaps is a documented open issue with no owner.

Key strategic facts:

- **Build on the active fork** [`fallout2-ce/fallout2-ce`](https://github.com/fallout2-ce/fallout2-ce), not the dormant upstream (`alexbatalov/fallout2-ce`, no commits since Feb 2025). The fork is 880 commits ahead, merged iPad touch work in April 2026, and accepts outside iOS PRs in ~2 weeks.
- **The license permits this** (Sustainable Use License: free, non-commercial distribution of modified builds — upstream ships IPAs itself). **The trademark does not permit the branding**: neutral name (VaultPad), original art, "Fallout 2" mentioned only descriptively.
- Users must supply their own legally purchased game data (GOG/Steam/Epic/CD). **No game assets are ever included or distributed.**
- Distribution: GitHub Releases + AltStore/SideStore first; TestFlight later; App Store as an optional attempt (~50–65% first-pass with strict hygiene, per ScummVM precedent) — never the load-bearing channel.
- Effort to a polished v1.0: **~58 engineer-days realistic** (34 optimistic / 111 pessimistic).

## Documents

| Document | What it is |
|---|---|
| **[docs/PRD.md](docs/PRD.md)** | The master document: executive verdict, current-state audit, gap analysis, architecture, numbered implementation roadmap, phased release plan, day-by-day first week, repo file map, risk register, effort estimates, go/no-go experiments, final recommendation, all 22 research areas, proposed scripts/CI |
| [docs/research/01](docs/research/01-build-system-ci-releases.md) | Build system, iOS platform layer, CI, release pipeline audit (upstream) |
| [docs/research/02](docs/research/02-licensing-distribution-appstore.md) | Licensing (SUL), copyright, trademark, App Store precedent, sideloading landscape |
| [docs/research/03](docs/research/03-input-touch-keyboard.md) | Touch/mouse/keyboard source audit — interaction-by-interaction |
| [docs/research/04](docs/research/04-rendering-audio-lifecycle-saves.md) | Rendering, display, audio, app lifecycle, filesystem, saves audit |
| [docs/research/05](docs/research/05-mod-compatibility.md) | Mod compatibility (sfall, Restoration Project, total conversions) |
| [docs/research/06](docs/research/06-ecosystem-community-names.md) | Repo health, forks, community demand, naming/trademark check |
| [docs/research/07](docs/research/07-fork-ios-audit.md) | The active fork's iOS layer: what it fixed, what remains open |

All research is source-grounded: file paths and line numbers from full clones of both repos, downloaded-and-inspected release artifacts, GitHub API data, and primary documents — access-dated 2026-07-17. Community reports are labeled anecdotal. Nothing herein is legal advice.

## Where to start (implementer)

Read [PRD §A](docs/PRD.md#a-executive-verdict) for the verdict, then execute [§G — the exact first-week plan](docs/PRD.md#g-exact-first-week-plan). Day 1 is: build the existing engine and run it on an iPad before designing anything.

## Legal posture

VaultPad is an unofficial, free, fair-code community project. It is not affiliated with, endorsed, or sponsored by Bethesda Softworks, ZeniMax Media, or Microsoft. Fallout is a registered trademark of ZeniMax Media Inc. This project contains and distributes no game content; a legally purchased copy of the original game is required. Engine code derives from Fallout 2 Community Edition under the [Sustainable Use License](https://github.com/fallout2-ce/fallout2-ce/blob/main/LICENSE.md).
