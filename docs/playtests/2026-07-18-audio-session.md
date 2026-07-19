# iPad audio-session regression — 2026-07-18

## Build under test

- Simulator: iPad Pro 11-inch (M4), iPadOS 18.5
- Bundle id: `com.chrissotraidis.vaultpad`
- SDL: 2.32.8
- Audio policy: `AVAudioSession.Category.playback`

## Checks

| Check | Result | Evidence |
|---|---|---|
| Product audio session activates before SDL | Pass | Simulator build linked AVFoundation and launched into the intro movie. |
| Background/resume during movie | Pass | Two consecutive Home → VaultPad cycles resumed the same running intro at later frames. |
| Process remains healthy | Pass | `simctl launch` returned the existing VaultPad process (`30704`) after both cycles. |
| Existing imported sandbox survives reinstall | Pass | Launch skipped onboarding and used the existing game-data container. |

## Coverage boundary

The Simulator pass proves integration, launch, background, and foreground stability. A real call/Siri interruption, Bluetooth route loss, silent-switch behavior, and device latency still require physical iPad hardware and must not be claimed as proven here.
