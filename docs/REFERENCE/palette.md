---
type: Reference
title: The 8-Color P3 Palette
description: The single source of color truth for Pushling — 8 Display P3 colors, their semantic roles, derived variants, and the palette-enforcement rule every visible pixel obeys.
status: Live
tags: [palette, color, p3, oled, visual]
timestamp: 2026-07-02T00:00:00Z
---

Every visible pixel in Pushling uses one of 8 named Display P3 colors, or an
alpha/blend variant of one against `void` — no exceptions. This is
`PushlingPalette` (`Pushling/Sources/Pushling/World/PushlingPalette.swift`),
tagged in source as **P3-T3-01: Palette enforcement**. This concept is the
single authority for color; other concepts reference it by name rather than
restating hex values.

# Schema

| Role | Constant | Hex (code-verified) | Usage |
|---|---|---|---|
| **Void** | `void_` | `#000000` | Background — OLED pixels OFF, true black |
| **Bone** | `bone` | `#F5F0E8` | Creature body — warm white, reserves pure white for emphasis |
| **Ember** | `ember` | `#FF4D00` | Fire accents, warnings, anger flush |
| **Moss** | `moss` | `#00E858` | Terrain, health indicators, contentment glow |
| **Tide** | `tide` | `#00D4FF` | Water, XP indicators, commit text, curiosity sparkle |
| **Gilt** | `gilt` | `#FFD700` | Stars, milestones, evolution flash, speech bubbles |
| **Dusk** | `dusk` | `#7B2FBE` | Night sky, magic effects, dream sequences |
| **Ash** | `ash` | `#5A5A5A` | Distant terrain, ghost echoes, whisper text |

All 8 are constructed as `SKColor(displayP3Red:green:blue:alpha:)` literals —
never `sRGB` initializers. P3 has a ~25% larger gamut than sRGB; higher
chroma gives better figure-ground separation at Touch Bar scale. **This is a
hard rule, not a preference: never regress a palette color to an sRGB
initializer.**

## Adjudicated: Moss blue channel

`PUSHLING_VISION.md` documents Moss as `#00E860`. The shipped constant is
`SKColor(displayP3Red: 0.0, green: 0.910, blue: 0.345, alpha: 1.0)`, which
converts to `#00E858` (`0.345 × 255 ≈ 88 = 0x58`, not `0x60 = 96`). Per DOCS
WIN, code is verified reality — **`#00E858` is canon**; the vision doc's
`#00E860` was an imprecise hand-rounding and is superseded here. This is a
small enough delta (B channel: 0.345 vs 0.376) to be invisible in practice,
but the hex value an implementer copies elsewhere (marketing, a website
swatch) should match the code, not the old doc.

# Derived Palette Colors

Two named derived colors exist, both built from `lerp()` rather than a fixed
hex — they are **not** independent 9th/10th palette entries, they're
documented blends of the 8:

| Name | Formula | Used for |
|---|---|---|
| `deepMoss` | `lerp(from: moss, to: void_, t: 0.3)` | Forest canopy tint (`BiomeManager.groundTint` for `.forest`) — see [biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md) |
| `softEmber` | `lerp(from: ember, to: bone, t: 0.4)` | Tongue / inner mouth color |

**Implementation note:** `lerp()` converts both endpoints to `.sRGB`
colorspace to read their RGB components (guards against a crash when one
side is a grayscale `SKColor`, e.g. `SKColor.black`), linearly interpolates
those sRGB-space components, then reconstructs the result as a new
`displayP3` color from those numbers. This mixes color spaces during the
blend — not colorimetrically pure — but the practical effect at these alpha
ranges is visually indistinguishable from a P3-native blend, and it is the
shipped behavior every consumer of `lerp()` inherits.

# General-Purpose Palette Operations

`PushlingPalette` exposes color-manipulation helpers used throughout the
rendering code — any concept describing a visual effect that "desaturates,"
"tints," or fades with distance is invoking one of these, not inventing a
new color:

| Function | Signature | Purpose |
|---|---|---|
| `lerp` | `(from: SKColor, to: SKColor, t: CGFloat) -> SKColor` | Linear interpolation between two colors, `t` clamped `[0,1]` |
| `withAlpha` | `(_ color: SKColor, alpha: CGFloat) -> SKColor` | The only sanctioned way to make a palette color transparent |
| `desaturate` | `(_ color: SKColor, amount: CGFloat) -> SKColor` | Blends a color toward `ash` — `amount: 0` = unchanged, `1` = fully gray |
| `atmosphericColor` | `(_ color: SKColor, depth: CGFloat) -> SKColor` | Combined desaturation (up to 50%) + alpha reduction (up to 40%) for distant elements — atmospheric perspective in one call |
| `tint` | `(_ base: SKColor, toward: SKColor, amount: CGFloat) -> SKColor` | Biome/context-specific tinting of a generic color |
| `stageColor` | `(for: GrowthStage) -> SKColor` | The palette color associated with a growth stage (evolution progress bars, stage-accent UI) — see [growth stages](/REFERENCE/growth-stages.md) |

## Stage → Color Mapping

`stageColor(for:)` is the canonical stage-accent mapping:

| Stage | Color |
|---|---|
| `egg` | Bone |
| `drop` | Tide |
| `critter` | Moss |
| `beast` | Ember |
| `sage` | Dusk |
| `apex` | Gilt |

# Palette Audit (Debug Builds Only)

`PushlingPalette.auditColor(_:context:)` is a `#if DEBUG`-gated self-check:
given an arbitrary `SKColor`, it walks all 8 palette entries plus every
pairwise `lerp` blend at 0.1 increments, and logs `NSLog` warning
`[Pushling/Palette] OFF-PALETTE color in %@` if nothing within a small
tolerance matches. This is a development-time guardrail enforcing the
"every pixel is one of 8 colors or a blend of them" rule described above —
it does not run in release builds and has no runtime cost there.

# Citations

[1] `Pushling/Sources/Pushling/World/PushlingPalette.swift`
[2] `PUSHLING_VISION.md` — Visual System: 8-Color P3 Palette
