---
type: Playbook
title: OLED Touch Bar Rendering Techniques
description: Rendering practices tuned for the Touch Bar's true-black OLED panel — texture caching, ambient-presence glow, stroke width, anti-aliasing policy, and the P3-never-sRGB rule.
status: Current
tags: [oled, rendering, spritekit, performance, p3]
timestamp: 2026-07-02T00:00:00Z
---

The Touch Bar's OLED panel has two properties that shape every rendering
decision in Pushling: pixels that are truly **off** emit zero light (not
"very dark," genuinely black), and the panel's **P3 wide color gamut** makes
saturated colors read as more vivid than the same colors on an sRGB display.
Hardware facts (resolution, panel type, sensors) live in
[Touch Bar hardware reference](/REFERENCE/touch-bar-hardware.md) — this
concept is the *technique* catalog: what to do with those facts when
rendering.

# The P3 Gamut Rule

**Never construct a palette color with an sRGB initializer.** The full color
authority — all 8 palette colors, their hex values, and the derived-color
formulas — is [the 8-color P3 palette](/REFERENCE/palette.md); every
technique below assumes colors are drawn from that palette. Higher chroma at
the same brightness gives better figure-ground separation at 30pt creature
height than an equivalent sRGB scene would.

# Texture Caching

`SKShapeNode` re-renders its path every frame — expensive at scale. The
recommended technique converts static shapes to baked textures once, then
reuses them as `SKSpriteNode`:

```swift
let texture = view.texture(from: shapeNode)
let sprite = SKSpriteNode(texture: texture)
```

Cache body/head/ear shapes at stage transition (they only change then); keep
eyes, mouth, and whiskers as live `SKShapeNode` since those animate every
frame and would need re-caching constantly. This roughly halves the
per-frame `SKShapeNode` render count for a fully cached creature.

**Status: designed, not yet built.** The only `texture(from:)` call in the
codebase today is a full-scene screenshot capture
(`Scene/PushlingScene.swift`), not per-body-part caching. This remains
correct forward-looking guidance — the highest-priority performance win not
yet claimed — not stale advice; it is preserved as intent-canon per the
project's aspirational-features rule.

# OLED-Specific Techniques

| Technique | Description | Stage Gate | Status |
|---|---|---|---|
| **Ambient presence** | Very large (3x creature size), very low alpha (0.02-0.04), additive circle. Invisible on an LCD; on OLED it creates a warm "presence" glow around the creature. | Beast+ | Designed, not yet built |
| **Edge softener** | The body shape re-drawn at 1.05x scale, same color, alpha 0.3-0.5. Creates a fur-like soft edge. | Critter+ | Designed, not yet built |
| **SDF glow** | A distance-from-edge glow effect, smoother than a shape-duplicate glow. | — | **Shipped**, as an `SKShapeNode`-based approximation rather than a literal signed-distance-field fragment shader — see `CreatureNode+Effects.swift` ("Phase 4.2"), owned in full by [the Enhanced 2.5D Rendering Stack](/SYSTEMS/rendering-stack-2-5d.md) |
| **Particle ambient** | 2-4 low-alpha, additive `SKEmitterNode` particles — "living warmth." | Sage+ | Designed, not yet built |

Ambient presence, edge softener, and particle ambient are preserved here as
intent-canon (designed-but-unbuilt), not pruned as stale — they remain the
plan for OLED-specific creature polish. SDF glow shipped ahead of the
original research doc's "Future" categorization; the shape-based
implementation detail belongs to the creature-rendering concept, not this
one.

## True Black and Stealth Effects

Because an OLED pixel that is off draws zero power and emits zero light,
`void` (`#000000`) is not merely a dark background color — it is literal
absence. This enables two effects, both from the hardware research and
still applicable:

- **Negative space as gameplay**: gaps between lit elements read as true
  voids, not "dark gray" — reinforcing the "emerges from darkness" art
  direction.
- **Stealth/invisible elements**: an element alpha-faded fully to `void`'s
  brightness is genuinely undetectable, not just dim — useful for elements
  that should be present (hit-testable) but visually absent.

Ambient glow effects (warm colors visible in a dark room) are a direct
consequence of the wide P3 gamut described in
[Touch Bar hardware reference](/REFERENCE/touch-bar-hardware.md) — this
concept only names the technique; the panel capability lives there.

# Stroke Width

Minimum stroke width is **0.75pt** (1.5 physical pixels at 2x Retina), not
0.5pt. Below 0.75pt, sub-pixel layout on the OLED panel causes visible color
fringing at the edges of a stroke.

# Anti-Aliasing Policy

- **Fills**: keep `isAntialiased = true`. The natural softness this
  produces reads as a fur-like edge rather than a rendering artifact.
- **Strokes**: `isAntialiased = false` is worth trying on straight lines for
  crisper edges, but curved elements (whiskers) should keep AA on — test at
  actual Touch Bar scale (30pt) before committing either way, since
  aliasing artifacts behave differently at this size than at desktop scale.

# Citations

[1] `Pushling/Sources/Pushling/World/PushlingPalette.swift`
[2] `Pushling/Sources/Pushling/Creature/CreatureNode+Effects.swift`
[3] `Pushling/Sources/Pushling/Scene/PushlingScene.swift`
[4] `docs/VECTOR-GRAPHICS-RESEARCH.md` — Sec 9 (OLED Rendering Techniques), the Ori Principle (Sec 3)
[5] `docs/TOUCHBAR-TECHNIQUES.md` — §10.4 (OLED Tricks)
