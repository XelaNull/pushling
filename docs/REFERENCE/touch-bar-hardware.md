---
type: Reference
title: Touch Bar Hardware Reference
description: Authoritative hardware facts about the MacBook Pro Touch Bar that constrain Pushling's rendering and input design — panel specs, touch controller, sensors, and model lifespan.
status: Live
tags: [hardware, touch-bar, oled, sensors]
timestamp: 2026-07-02T00:00:00Z
---

The MacBook Pro Touch Bar is a small OLED strip with a capacitive touch
overlay. Every constraint in this concept is a hard physical fact, not a
design choice — the rendering techniques and interaction model built on top
of it are documented separately (see cross-links below).

# Schema

| Spec | Value |
|---|---|
| Display type | OLED — true blacks, P3 wide color gamut |
| Resolution | 2170 x 60 pixels (1085 x 30 points @2x Retina) |
| Physical size | ~310mm x 10mm (~12.2" x 0.4") |
| Touch controller | Broadcom BCM5976TC1KUB60G (same family as iPhone/iPad) |
| Multi-touch | Hardware supports 10-point; the strip's width limits practical simultaneous use to 2-3 |
| Force / pressure | **None** — purely capacitive, binary touch detection |
| Haptic feedback | **None on the Touch Bar itself** — see caveat below |
| Processor generation | T1 chip (2016-17) / T2 (2018-20) / Apple Silicon (2020+) |
| Display interface | MIPI DSI, single-lane, command mode — receives raw BGR24 pixels |
| OLED response time | ~0.03ms (nanosecond-class switching) |
| Introduced | October 2016 (MacBook Pro) |
| Discontinued | October 2023 (last model: M2 MacBook Pro 13") |

Pushling targets the full 1085 x 30 point scene at this resolution — see
[Pushling's system architecture](/ARCHITECTURE/system-architecture.md) for
the rendering-target table (engine, frame rate, scene size as consumed by
the daemon).

# Key Hardware Facts

- **True blacks are literal**: an OLED pixel that is off emits zero light —
  not "very dark." This is the physical basis for the true-black art
  direction; see [OLED rendering techniques](/REFERENCE/oled-rendering-techniques.md)
  for what that enables.
- **P3 wide color**: the panel's gamut is roughly 25% larger than sRGB —
  colors render more vividly than the same values would on the main
  display. Pushling's entire palette is P3-native for this reason — see
  [the 8-color palette](/REFERENCE/palette.md).
- **The strip is narrow** (~10mm tall): vertical gesture resolution is
  limited; horizontal is the primary interaction axis.
- **Fully reverse-engineered**: independent researcher Wenting Zhang drove
  the OLED panel standalone using an RP2040 microcontroller, with the
  findings published open-source — confirming the panel has no hidden
  rendering restrictions beyond what the MIPI DSI interface itself imposes.
- **The Touch Bar has no haptic hardware of its own.** Tactile "feedback"
  associated with the Touch Bar (e.g. HapticKey-style click confirmation) is
  achieved only by triggering the **trackpad's** Taptic Engine via the
  private `MultitouchSupport.framework`, which exposes 8 haptic types
  (`back`, `click`, `weak`, `medium`, `weakMedium`, `strong`, `reserved1`,
  `reserved2`). Any future pet-touch haptic feedback would ride the
  trackpad, not the strip itself — see
  [the private-API mechanism](/REFERENCE/touch-bar-private-api.md#trackpad-haptics-not-touch-bar-haptics)
  for how that framework is invoked. (A prior-art comparison elsewhere in
  the bundle lists "Haptic feedback: Yes (private API)" for Pushling without
  this distinction — treat that as needing the same correction.)

# Sensor Availability

| Sensor | Access Method | Hardware Availability | Wired in Pushling? |
|---|---|---|---|
| Ambient light | `ioreg` | All Touch Bar-equipped MacBooks | **Not yet** — no ambient-light code exists in the codebase today; remains a designed-but-unbuilt "pet by covering the sensor" interaction |
| Accelerometer | IOKit HID, ~800Hz | **Apple Silicon only** | **Not yet** — same status |
| Camera (face detection) | Vision framework | All Touch Bar-equipped MacBooks | **Not yet** — no camera/Vision-framework code exists in the codebase today; remains a designed-but-unbuilt "face detected = the creature notices you" interaction |

**The accelerometer caveat matters**: the Touch Bar only ever shipped on
Intel and M1 MacBook Pros. Since the accelerometer requires Apple Silicon,
the hardware overlap where *both* a Touch Bar and an accelerometer exist is
specifically the **M1 MacBook Pro 13" (2020)** — a narrow target if this
sensor is ever wired up. All three sensors are preserved here as
intent-canon (aspirational, not stale) per the project's rule that
designed-but-unbuilt capabilities are not pruned.

# Citations

[1] `docs/archive/TOUCHBAR-TECHNIQUES.md` — §2 (Hardware Specifications), §3.1 (MTMR Hidden Features), §6.5 (Haptic Feedback), §10.3 (Sensor Input), §10.4 (OLED Tricks)
[2] `Pushling/Sources/Pushling/TouchBar/TouchBarController.swift` (scene dimensions, `preferredFramesPerSecond`)
