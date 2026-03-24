# Vector Graphics & Creature Visual Design Research

**Compiled**: 2026-03-23 | **Workers**: 10 parallel research agents | **Scope**: Vector cat design, skeleton animation, stage progression, OLED rendering, codebase grading

---

## Table of Contents

1. [Bugs Found](#1-bugs-found)
2. [Dead Code to Wire Up](#2-dead-code-to-wire-up)
3. [Design Philosophy](#3-design-philosophy)
4. [Proportions & Shape Language](#4-proportions--shape-language)
5. [Stage-by-Stage Recommendations](#5-stage-by-stage-recommendations)
6. [Feature Introduction Timeline](#6-feature-introduction-timeline)
7. [Animation Architecture](#7-animation-architecture)
8. [Procedural Animation Formulas](#8-procedural-animation-formulas)
9. [OLED Rendering Techniques](#9-oled-rendering-techniques)
10. [Codebase Grades](#10-codebase-grades)
11. [Implementation Priority](#11-implementation-priority)
12. [Sources](#12-sources)

---

## 1. Bugs Found

### BUG-1: `makeCatBody` always uses `.beast` stage proportions (HIGH)

**File**: `ShapeFactory.swift:25`

`makeCatBody` calls `CatShapes.catBody(width:height:stage:)` but always passes `stage: .beast` (the default parameter). No caller overrides it. This means the per-stage body proportions in `CatShapes.catBody()` (Critter's rotund belly `shoulderBump: 0.05`, Sage's elegant silhouette `shoulderBump: 0.08, haunchWidth: 0.85`, Apex's flowing lines `shoulderBump: 0.06, haunchWidth: 0.88`) are **dead code**. Every cat stage renders with Beast's body shape.

**Fix**: Pass the actual `stage` parameter through `makeCatBody` and from `buildCritter/buildSage/buildApex` in `StageRenderer.swift`.

### BUG-2: Egg `coreGlow` returned as `nil` in StageNodes (MEDIUM)

**File**: `StageRenderer.swift:110`

The core glow node is created and added as a child of the body, but `StageNodes` returns `coreGlow: nil`. This means `CreatureNode.updateCoreGlow()` never finds the node via `coreGlowNode`. The egg's only expressive feature (pulsing inner light) is broken.

**Fix**: Return the actual `coreGlow` node in the StageNodes struct.

### BUG-3: Head color hardcoded to `PushlingPalette.bone` (MEDIUM)

**Files**: `StageRenderer.swift` lines 205, 286, 372, 477

Every cat stage's `headShape` uses hardcoded `PushlingPalette.bone` while the body uses `bodyColor` (derived from `visualTraits.baseColorHue`). If a creature has a blue/green tint, its head is white while its body is tinted.

**Fix**: Pass `bodyColor` to head shape construction.

### BUG-4: `tongue_blep` registered for Drop but Drop has no mouth (LOW)

**File**: `BehaviorSelector.swift`

`tongue_blep` behavior is available at Drop stage but Drop has `hasMouth: false`. MouthController is nil, so setState calls are silent no-ops.

**Fix**: Gate `tongue_blep` behind `.critter` minimum stage, or add a simple mouth to Drop.

---

## 2. Dead Code to Wire Up

These features are fully implemented but never called:

| Feature | Implementation | Location | Why Wire It |
|---------|---------------|----------|-------------|
| **Nose** | `ShapeFactory.makeNose()` | ShapeFactory.swift:116-126 | Central face anchor, inverted triangle in `softEmber` |
| **Legs** | `CatShapes.catLeg()` | CatShapes.swift:468-510 | Connects paws to body. Front legs taper straight, back legs have thigh bulge |
| **Fur texture** | `CatShapes.furTexture()` | CatShapes.swift:618-639 | Directional strokes along body contour |
| **Toe pads** | `makePaw(showToes: true)` | ShapeFactory.swift:275-317 | 3 toe pads + 1 central pad in `softEmber` |
| **Mouth smile** | `MouthController.setState("smile")` | MouthController.swift | Never triggered by emotional states |
| **Mouth frown** | `MouthController.setState("frown")` | MouthController.swift | Never triggered by emotional states |
| **Mouth yawn** | `MouthController.setState("yawn")` | MouthController.swift | Never triggered by any behavior |
| **Proto-ear triangle** | `makeProtoEarTriangle()` | ShapeFactory.swift:351-369 | Exists but Drop uses circles instead |
| **Stage body proportions** | `CatShapes.catBody(stage:)` | CatShapes.swift:33-63 | Dead due to BUG-1 above |

---

## 3. Design Philosophy

### The Solid Fill Test (North Star)

Render the creature as one flat color at actual Touch Bar scale. If it doesn't instantly read as its intended form (egg, blob, kitten, cat, spirit), simplify until it does. At 30pt tall, silhouette is basically all you get. Detail is a bonus.

### One New Feature Per Stage

Each evolution should feel like an event. Borrowed from Pokemon evolution design:

| Transition | The ONE New Signature Feature |
|-----------|-------------------------------|
| Egg -> Drop | **Eyes appear** (life begins) |
| Drop -> Critter | **Cat silhouette forms** (ears + tail + paws) |
| Critter -> Beast | **Whiskers + mouth + aura appear** (maturity) |
| Beast -> Sage | **Third eye mark appears** (wisdom) |
| Sage -> Apex | **Multi-tails + crown + ethereal body** (transcendence) |

### Shape Language Arc

The progression is NOT a linear march from round to angular. It's a narrative arc:

| Stage | Dominant Shape | Why |
|-------|---------------|-----|
| Egg | Pure circle/oval | Safety, potential, dormancy |
| Drop | Circle + upward point | Emergence, vulnerability |
| Critter | Circle + triangle ears | Innocence with emerging alertness |
| Beast | Circle + triangle blend | Confidence, capability, personality |
| Sage | **Return to rounder** + flowing curves | Wisdom transcends power |
| Apex | Flowing spirals + dissolved edges | Beyond fixed geometry |

**Key insight from Ghibli**: Power is expressed through subtraction, not addition. The Sage should be simpler than the Beast, not more complex. The most powerful spirits in Miyazaki's world are the most abstract.

### Animation Over Detail

At 30pt tall, movement matters infinitely more than pixels. Celeste's Madeline has no face but is incredibly expressive. Invest in rich animation: breathing, ear flicks, tail curls, head tilts, squash-and-stretch. Timing matters more than frame count.

### The Ori Principle

Pure self-luminous silhouette on dark background. The creature IS the light source. On OLED true black, this is maximally effective. Any non-black pixel literally glows against the void.

---

## 4. Proportions & Shape Language

### Current Proportions (Validated as Good)

| Stage | Size (pts) | Head % Height | Ear % Head | Eye Radius |
|-------|-----------|:---:|:---:|:---:|
| Critter | 14x16 | 52% | 48% | 1.2pt |
| Beast | 18x20 | 45% | 56% | 1.5pt |
| Sage | 22x24 | 40% | 63% | 1.5pt |
| Apex | 25x28 | 36% | 70% | 1.8pt |

Head percentage correctly decreases (kitten -> adult). Ear-to-head ratio correctly increases (spirit-cat aesthetic). These are well-calibrated.

### Critical Ratio: Ears

- Keep ear height at **33-45%** of head diameter for "cat" territory
- Above **50%** reads as "fox"
- Above **60%** reads as "rabbit"
- Our current 48-70% range is high but correct for a stylized spirit-cat on OLED where ears are the primary visual anchor
- Ear outer edge must be **convex** (our code correctly does this). Concave = bat/demon

### Cat Identity: The 5 Identifiers (Priority Order)

1. **Pointed triangular ears** (the single most important feature)
2. **Curved tail** (S-curve or question-mark posture)
3. **Spine S-curve** (flexible, arched back)
4. **Compact rounded body** with shoulder/haunch definition
5. **Round head with cheek taper** to small chin

### Chibi Proportions for Our Scale

At 28-56px @2x, the ideal proportions are:
- Head: 40-60% of total height (the bigger, the cuter)
- Body: 30-40% of total height
- Legs: 10-20% of total height
- Eyes: largest facial feature, 25-40% of head width

### Vector Advantage

Since we use Bezier paths (not pixels), sub-pixel antialiasing gives us effectively 1.5-2x the expressiveness of equivalent pixel art at the same dimensions. SpriteKit renders at floating-point coordinates, so a 0.3pt movement shifts antialiased edges for perceived motion without full-pixel jumps.

---

## 5. Stage-by-Stage Recommendations

### Egg (9x11pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| Core glow | Broken (BUG-2) | **Fix**: return actual node in StageNodes |
| Stroke color | Off-palette `SKColor(white: 0.7, alpha: 0.3)` | Use `PushlingPalette.ash` at 0.15 alpha |
| Wobble | None | Add wobble that intensifies as XP approaches hatch |
| Bounce | None | Add bounce physics during movement (vision says "bouncy egg") |
| Crack marks | None | Add subtle crack lines at 60% and 80% of hatch threshold |
| Eye nodes | 12 invisible nodes allocated | Skip full eye creation, just pass empty containers |

### Drop (10x12pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| Proto-ears | Circles at alpha 0.3 (invisible) | Make structural: slight widening in teardrop Bezier path itself |
| Proto-tail | 3pt at alpha 0.2 (invisible) | Reduce to 1-2pt nub at alpha 0.3 |
| Locomotion | Slides across bar | **Hop/bounce** locomotion (teardrop should bounce, not slide) |
| Core glow | None (lost from Egg) | Add subtle inner shimmer |
| Eyes | 1.0pt radius | Consider increasing to 1.2pt (eyes ARE the face at this scale) |
| Body | Fully opaque | Semi-translucent (alpha 0.88-0.92) — still partly energy |

### Critter (14x16pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| **Whiskers** | 2 stubs, 2pt length | **Remove entirely** — save for Beast as "new feature" moment |
| **Mouth** | Always visible | **Remove** or gate behind emote state (at 2.1pt it's invisible noise) |
| Head color | Hardcoded bone (BUG-3) | Use `bodyColor` |
| Head ratio | `w * 0.3` (52%) | Increase to `w * 0.35` (~58%) for stronger baby schema |
| Eye catch-light | `radius * 0.12` | Increase to `radius * 0.18` for visible "life spark" |
| Nose | Missing | Consider adding tiny `makeNose()` to anchor the face |
| Paws | Plain beans | Make rounder (circles not ovals) for kitten feel |

### Beast (18x20pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| **Whiskers** | 3/side, 5pt | Keep — this is where whiskers debut as NEW feature |
| **Mouth** | Present | Keep — debuts here with whiskers as maturity markers |
| Nose | Missing | **Add** via `makeNose()` |
| Legs | Paws float disconnected | **Wire up** `CatShapes.catLeg()` with `legHeight > 0` |
| Toe pads | `showToes: false` | Enable `showToes: true` on all paws |
| Fur texture | Never called | Add `furTexture(density: 0.2)` overlay at 0.15 alpha |
| Aura | Static circle | Add slow alpha pulse (2-3% oscillation over 4s) |
| Body proportions | Uses Beast defaults (correct by accident due to BUG-1) | Fix BUG-1 so this is intentional |
| Walk style | Same as Critter | Add distinctive swagger — longer stride, tail held higher |

### Sage (22x24pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| Body proportions | Same as Beast (BUG-1) | Fix BUG-1: `shoulderBump: 0.08, haunchWidth: 0.85` (elegant, not muscular) |
| Third eye | Static position | Make it **respond to emotions** (brighter when curious, dimmer when sleepy) |
| **Orbiting particles** | None | Add 3-5 dusk-colored dots in slow 8-12s orbit (key Sage differentiator) |
| **Luminous fur tips** | None | Add 6-8 thin additive-blend lines at body edge, pulsing with breath |
| Default eye state | Same as Beast (fully open) | **Half-lidded default** — the Sage has "seen everything" |
| Aura shape | Circle (same as Beast) | Change to **vertical oval** (suggests upward spiritual energy) |
| Aura color | Gilt (correct) | Keep |
| Head position | `y: h * 0.28` | Raise to `y: h * 0.32` for dignified, high-held posture |
| Ear tips | Same as Beast | Make **taller and more tapered** (Siamese elegance) |
| **Behaviors** | Same as Critter/Beast (zoomies, tail chase, etc.) | **Add Sage-exclusive**: meditation, contemplation, knowing slow-blink. Make zoomies much rarer. |

### Apex (25x28pt)

| Aspect | Current | Recommended |
|--------|---------|-------------|
| Body alpha | Static 0.85 | **Oscillate 0.78-0.92** per-frame (flickering between realms) |
| Body proportions | Same as Beast (BUG-1) | Fix BUG-1: `shoulderBump: 0.06, haunchWidth: 0.88` |
| Multi-tails | Up to 9, all similar alpha | **Cap visible at 5**. Fade alpha per tail (0.8, 0.7, 0.6...) |
| Extra tails | Static S-curves with zRotation sine | Consider segmented spring physics per tail |
| **Particle dissolution** | None | Pre-create 15-20 particle pool, cycle 3-5 through detach-drift-fade-reset |
| Crown stars | 5 circles | Change to **diamond shapes** (4-point). Add faint connecting arc |
| Crown behavior | Fixed position, only alpha pulses | Make reactive: flare on events, dim during sleep |
| Eye glow | None | Add faint glow node behind each eye (2.5pt, alpha 0.15) |
| Aura | Bone-colored circle | Change to **gilt** (regression from Sage's golden aura). Consider pulsing ring |
| **Behaviors** | Same as all cat stages | **Add Apex-exclusive**: ethereal float, phase-shift, cosmic awareness. Multi-tail should express emotion (fan wide = confident, wrap tight = concerned) |

---

## 6. Feature Introduction Timeline

| Feature | Egg | Drop | Critter | Beast | Sage | Apex |
|---------|:---:|:----:|:-------:|:-----:|:----:|:----:|
| Body shape | Oval | Teardrop | Round cat | Elongated + shoulder | Elegant + slim | Ethereal + ghost echo |
| Eyes | Hidden | Large, round | Very large | Almond + slit pupil | Half-lidded default | Almond + glow |
| Ears | None | Bumps in path | Small triangles | Taller, sharper | Tall, tapered | Tall, tapered |
| Tail | None | 1px nub | Short stub | Full S-curve | Long, tapered | Multi-tail fan |
| Paws | None | None | Round blobs | Defined + toes | Defined | Defined |
| Whiskers | None | None | **None** | **NEW**: 3/side | 3/side + curl | 3/side, longer |
| Mouth | None | None | **None** | **NEW**: small | Small | Small |
| Nose | None | None | Optional | **NEW** | Yes | Yes |
| Core glow | Pulsing | Shimmer | Faint chest | None (-> aura) | None | None |
| Aura | None | None | None | **NEW**: warm | Golden oval | Pulsing ring |
| Third eye | None | None | None | None | **NEW** | Crown of stars |
| Particles | None | None | None | None | **NEW**: orbiting | Dissolution + orbit |
| Transparency | Opaque | Semi | Opaque | Opaque | Opaque | Ethereal (waving) |

---

## 7. Animation Architecture

### Skeleton Upgrade (Phased)

**Phase 1: Spine Chain** (Highest Impact)
Add `hipBone` + `chestBone` between creature root and head. Counter-rotate during walk for spine undulation. Head bobs as child of chest with overlapping delay.

```
hipBone.zRotation = sin(walkPhase) * 0.04         // +/- 2.3 degrees
chestBone.zRotation = sin(walkPhase + .pi) * 0.03 // counter-phase
headBone.position.y = baseY + sin(walkPhase * 2 + .pi/2 + 0.15) * 0.3
```

**Phase 2: Two-Bone IK Legs**
Use `CatShapes.catLeg()` with law-of-cosines IK solving. Paw position drives IK target. ~6 trig calls per leg per frame (trivially fast).

**Phase 3: Squash & Stretch**
Volume-preserving: `scaleY = 1 + amount * 0.08`, `scaleX = 1 / scaleY`. Compose multiplicatively with breathing.

**Phase 4: Halflife Springs**
Upgrade all spring constants to halflife-based formulation for framerate independence.

### Performance Cost
+0.5ms estimated (~5-8 empty SKNode bone containers, ~20 extra trig calls). We're at 5.7ms of 16.6ms budget.

### What NOT to Do
- Don't adopt Spine/DragonBones runtime (overkill for one creature)
- Don't replace our BodyPartController protocol (it works well)
- Don't use SpriteKit's built-in `SKAction.reach()` IK (action-based, not per-frame)
- Don't use Verlet for tail (our spring-damper gives better artistic control)

---

## 8. Procedural Animation Formulas

### Critical Spring (Universal Animation Primitive)

```swift
func criticalSpringDamper(
    value: inout CGFloat, velocity: inout CGFloat,
    target: CGFloat, halflife: CGFloat, dt: CGFloat
) {
    let d = (4.0 * 0.6931) / (halflife + 1e-5)
    let y = d / 2.0
    let j0 = value - target
    let j1 = velocity + j0 * y
    let eydt = fastNegExp(y * dt)
    value = eydt * (j0 + j1 * dt) + target
    velocity = eydt * (velocity - j1 * y * dt)
}

func fastNegExp(_ x: CGFloat) -> CGFloat {
    return 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
}
```

### Halflife Guide

| Animation | Halflife | Character |
|-----------|----------|-----------|
| Ear reflexes, startle | 0.05-0.10s | Snappy |
| Expression transitions | 0.10-0.20s | Responsive |
| Walk-to-idle blending | 0.15-0.30s | Smooth |
| Mood changes | 0.30-0.50s | Gradual |

### Under-Damped Spring (For Bounce)

```swift
func underDampedSpring(
    value: inout CGFloat, velocity: inout CGFloat,
    target: CGFloat, stiffness: CGFloat, damping: CGFloat, dt: CGFloat
) {
    let f = 1.0 + 2.0 * dt * damping
    let oo = stiffness
    let hoo = dt * oo
    let hhoo = dt * hoo
    let detInv = 1.0 / (f + hhoo)
    let detX = f * value + dt * velocity + hhoo * target
    let detV = velocity + hoo * (target - value)
    value = detX * detInv
    velocity = detV * detInv
}
```

### Spring Presets

| Use Case | Type | Params |
|----------|------|--------|
| Happy bounce | Under-damped | ratio 0.35, 4 Hz |
| Landing squash | Under-damped | ratio 0.45, 5 Hz |
| Startle jump | Under-damped | ratio 0.5, 6 Hz |
| Sad droop | Critical | halflife 0.4s |
| Tail settle | Critical | halflife 0.15s |
| Head tracking | Critical | halflife 0.1-0.2s |

### NoiseIdleSystem (Layered Organic Micro-Movements)

Three-octave sine noise with irrational frequency ratios applied additively to all body parts. Each body part has a random phase offset so they never move in sync. Frequencies: body 0.3Hz, head 0.4Hz, ears 0.5Hz, whiskers 0.8Hz. Amplitude reduced during walk (0.3x) and sleep (0.1x).

### Follow-Through (Ears/Whiskers)

Track body velocity, apply proportional drag offset via critical spring:

```swift
let dragTarget = -bodyVelocityX * 0.008  // 8 milliradians per pt/s
criticalSpringDamper(value: &followAngle, velocity: &followVel,
                     target: dragTarget, halflife: 0.08, dt: dt)
earNode.zRotation = stateRotation + followAngle
```

Whiskers additionally respond to acceleration (twitch on sudden movement).

### Emotion-to-Movement Mapping

Map 4 emotional axes to physical parameters:

| Emotion State | Breath Period | Idle Amplitude | Speed | Spring Halflife | Vertical Bias |
|--------------|:---:|:---:|:---:|:---:|:---:|
| Happy (high satisfaction + content) | 2.5s | 1.2x | 1.3x | 0.08s (snappy) | +2pt (up) |
| Sad (low satisfaction) | 3.8s | 0.5x | 0.6x | 0.4s (sluggish) | -1pt (droop) |
| Anxious (low energy + low satisfaction) | 1.5s | 1.0x | Variable | 0.15s | -0.5pt + tremor |
| Content (high contentment, mid energy) | 3.0s | 0.9x | 0.8x | 0.2s | 0pt |
| Excited (high energy + curiosity) | 2.0s | 1.5x | 1.5x | 0.06s | +1pt |

### Squash-Stretch (Volume-Preserving)

```swift
let stretch = clamp(velocityY * 0.003, -0.15, 0.15)
bodyNode.yScale = breathScale * (1.0 + stretch)
bodyNode.xScale = 1.0 / (1.0 + stretch)
```

### Asymmetric Breathing

Inhale = 40% of cycle (faster, ease-in). Exhale = 60% (slower, ease-out). Creates organic rhythm vs robotic sine wave.

---

## 9. OLED Rendering Techniques

### Texture Caching (Highest Priority Performance Win)

SKShapeNode re-renders every frame. Convert static body shapes to textures:

```swift
let texture = view.texture(from: shapeNode)
let sprite = SKSpriteNode(texture: texture)
```

Cache body, head, ears at stage transition. Keep eyes/mouth/whiskers as SKShapeNode (they animate per-frame). Halves per-frame SKShapeNode render count.

### OLED-Specific Techniques

| Technique | Description | Stage Gate |
|-----------|-------------|------------|
| **Ambient presence** | Very large (3x creature), very low alpha (0.02-0.04), additive circle. Invisible on LCD, creates warm "presence" on OLED. | Beast+ |
| **Edge softener** | Body shape at 1.05x scale, same color, alpha 0.3-0.5. Creates fur-like soft edges. | Critter+ |
| **SDF glow shader** | Fragment shader computing distance from edge. Smoother than shape-duplicate glow. | Future |
| **Particle ambient** | 2-4 particle SKEmitterNode, additive, very low alpha. "Living warmth." | Sage+ |

### Stroke Width

Raise minimum from 0.5pt to **0.75pt** (1.5 physical pixels at 2x). Below this, subpixel layout causes color fringing on OLED.

### Anti-Aliasing

- **Fills**: Keep `isAntialiased = true` (natural softness creates fur illusion)
- **Strokes**: Consider `isAntialiased = false` for straight lines (crisper), but test at actual Touch Bar scale before committing
- Curved elements (whiskers) should keep AA on

### P3 Gamut

25% larger color surface than sRGB. Higher chroma = better figure-ground separation at small sizes. Current all-P3 palette is correct. Never change to sRGB initializers.

---

## 10. Codebase Grades

### Visual Quality (Grader 1)

| Stage | Recognizability | Distinctiveness | Expressiveness | Readability | Overall |
|-------|:-:|:-:|:-:|:-:|:-:|
| Egg | B+ | A | D | C+ | **C+** |
| Drop | B | B+ | C+ | B- | **B-** |
| Critter | A- | A | A- | B+ | **A-** |
| Beast | A | B+ | A | A- | **A-** |
| Sage | A | B | A | A | **B+** |
| Apex | A | A- | A | A | **A-** |

### Expression & Animation (Grader 2)

| Stage | Expression Range | Animation Variety | Breathing | Movement | Stage-Appropriate | Composite |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|
| Egg | F | D- | B- | D | D+ | **D** |
| Drop | C | C- | B | D+ | C- | **C-** |
| Critter | B+ | A- | A- | A- | A- | **A-** |
| Beast | B+ | A | A | A | B+ | **A-** |
| Sage | B | B | A | B+ | C+ | **B** |
| Apex | B | B- | A | B | C | **B-** |

### Key Pattern: Middle-Heavy Curve

Critter and Beast are excellent. Early stages (Egg, Drop) are too static. Late stages (Sage, Apex) are cosmetically decorated but behaviorally undifferentiated -- they do the same zoomies and tail chasing as a kitten, breaking the wisdom/transcendence fantasy.

---

## 11. Implementation Priority

### Tier 1: Bug Fixes (Do First)

1. Fix `makeCatBody` to pass actual `stage` parameter
2. Fix Egg `coreGlow: nil` in StageNodes
3. Fix head color to use `bodyColor` instead of hardcoded bone

### Tier 2: Quick Visual Wins (High Impact, Low Effort)

4. Increase Critter catch-light radius (`0.12` -> `0.18`)
5. Raise minimum stroke width to 0.75pt
6. Remove whiskers/mouth from Critter (save for Beast debut)
7. Add nose via `makeNose()` at Beast+
8. Enable `showToes: true` at Beast+
9. Wire up legs via `catLeg()` with `legHeight > 0`

### Tier 3: Stage Differentiation (High Impact, Medium Effort)

10. Sage orbiting wisdom particles (3-5 dusk dots)
11. Sage half-lidded default eye state
12. Sage-exclusive behaviors (meditation, contemplation)
13. Apex waving alpha (0.78-0.92)
14. Apex particle dissolution pool
15. Drop hop/bounce locomotion
16. Egg wobble intensifying toward hatch

### Tier 4: Animation Upgrades (High Impact, Higher Effort)

17. NoiseIdleSystem (layered sine micro-movements)
18. Follow-through springs on ears/whiskers
19. Spine chain (hip + chest bones) for walk undulation
20. Squash-stretch from velocity
21. Asymmetric breathing
22. Emotion-to-movement parameter mapping
23. Two-bone IK legs
24. Inertialization in BlendController

### Tier 5: OLED Polish

25. Texture caching for static body shapes
26. Ambient presence layer (alpha 0.02-0.04)
27. Edge softener layer for fur illusion
28. SDF glow shader (future)

---

## 12. Sources

### Cat Anatomy & Proportions
- [How to Draw Animals: Cats and Their Anatomy (Envato Tuts+)](https://design.tutsplus.com/articles/how-to-draw-animals-cats-and-their-anatomy--vector-17417)
- [How to Draw Cute Animal Ears (MediBang Paint)](https://medibangpaint.com/en/use/2023/05/cute-animal-ears/)
- [Cat Tail Types (Catster)](https://www.catster.com/lifestyle/common-cat-tail-types/)
- [Cat Sprite Style Guide (ClanGen)](https://clangen.io/docs/dev/art/cat-sprites/cat-sprites/)

### Pixel Art & Small-Scale Design
- [How to Create 16x16 Pixel Art (Sprite-AI)](https://www.sprite-ai.art/guides/how-to-create-16x16-pixel-art)
- [Pixelblog 47 - Tiny Pixels (SLYNYRD)](https://www.slynyrd.com/blog/2023/11/26/pixelblog-47-tiny-pixels)
- [Fix My Sprite Volume 3 (2D Will Never Die)](https://2dwillneverdie.com/tutorial/fix-my-sprite-volume-3/)
- [2D Pixel Art Style Guide for Games (Sprite-AI)](https://www.sprite-ai.art/blog/2d-pixel-art-style-guide)
- [Squash and Stretch Pixel Art (Lospec)](https://lospec.com/pixel-art-tutorials/squash-and-stretch-by-pedro-medeiros)

### Game Creature Design
- [Game Design Breakdown: Neko Atsume](https://alexiamandeville.medium.com/game-design-breakdown-the-simplicity-of-neko-atsume-a8616a937a47)
- [GDC 2015: Animating Ori and the Blind Forest](https://zyzyz.github.io/en/2018/01/GDC2015-Animating-Ori/)
- [Visual Design of Games: Hollow Knight](https://mechanicsofmagic.com/2023/04/18/visual-design-of-games-hollow-knight/)
- [Art Direction Analysis of Hyper Light Drifter](http://idrawwearinghats.blogspot.com/2014/04/art-direction-analysis-of-hyper-light.html)
- [Pokemon Design Lessons from 30 Years (Creative Bloq)](https://www.creativebloq.com/art/digital-art/what-artists-can-learn-from-30-years-of-pokemon-character-design)
- [Creature Feature: Animal Well Pixel Art (Game Developer)](https://www.gamedeveloper.com/art/creature-feature-the-surreal-pixel-art-and-animation-of-animal-well)

### Shape Language & Character Design
- [Character Shape Language (CG-Wire)](https://blog.cg-wire.com/character-shape-language/)
- [Shape Language in Character Design (Dream Farm Studios)](https://dreamfarmstudios.com/blog/shape-language-in-character-design/)
- [Mastering Cartoon Cat Character Design (Oboe)](https://oboe.com/learn/mastering-cartoon-cat-character-design-28knkn/study-guide)

### Ghibli & Spirit Design
- [Ghibli Spirit Design Analysis](https://andycbrennan.wordpress.com/2015/10/11/spirited-away-princess-mononoke-the-spirits/)
- [Kitsune Mythology and Powers (StorytellingDB)](https://storytellingdb.com/kitsune-japanese-mythology/)

### Animation & Springs
- [Spring-It-On: Game Developer's Spring Roll-Call (Daniel Holden)](https://theorangeduck.com/page/spring-roll-call)
- [Game Math: Precise Control over Numeric Springing (Allen Chou)](https://allenchou.net/2015/04/game-math-precise-control-over-numeric-springing/)
- [Cat Walk Cycle Animation Tutorial (Rusty Animator)](https://rustyanimator.com/cat-walk-cycle/)
- [Quadrupeds' Gaits Guide (Animator Notebook)](https://www.animatornotebook.com/learn/quadrupeds-gaits)
- [Procedural Animation in Trifox](https://www.trifox-game.com/exploring-procedural-animation-in-trifox/)
- [Breathing Life into Idle Animations (AnimSchool)](https://blog.animschool.edu/2024/06/14/breathing-life-into-idle-animations/)

### IK & Skeleton
- [SpriteKit and Inverse Kinematics (Kodeco)](https://www.kodeco.com/1158-spritekit-and-inverse-kinematics-with-swift)
- [Inverse Kinematics in 2D (Alan Zucconi)](https://www.alanzucconi.com/2018/05/02/ik-2d-1/)
- [Two-Bone IK (Little Polygon)](https://blog.littlepolygon.com/posts/twobone/)
- [FABRIK IK Solver (dev.to)](https://dev.to/dslower/inverse-kinematics-solver-using-the-fabrik-method-1m92)

### OLED & SpriteKit Rendering
- [Achieving 60 FPS with Procedural Vectors in SpriteKit (Glowmatic)](https://blog.glowmatic.net/2020/02/achieving-60-fps-with-procedural-vector.html)
- [15 Tips to Optimize Your SpriteKit Game (Hacking with Swift)](https://www.hackingwithswift.com/articles/184/tips-to-optimize-your-spritekit-game)
- [A Quick Fix for Fuzzy SKShapeNode Lines (Adam Preble)](http://adampreble.net/blog/2015/02/a-quick-fix-for-fuzzy-skshapenode-lines/)
- [Adding Glow to SKSpriteNode (Augmented Code)](https://augmentedcode.io/2018/01/17/adding-an-animating-glow-to-skspritenode/)
- [Get Started with Display P3 - WWDC17 (Apple)](https://developer.apple.com/videos/play/wwdc2017/821/)
- [LearnOpenGL - Bloom](https://learnopengl.com/Advanced-Lighting/Bloom)

### Emotion & Movement Research
- [The EMOTE Model for Effort and Shape (CMU)](http://graphics.cs.cmu.edu/nsp/course/15-464/Fall05/papers/chi00emote.pdf)
- [Evaluating Emotive Character Animations (Lin et al., IVA 2009)](https://link.springer.com/chapter/10.1007/978-3-642-04380-2_33)
