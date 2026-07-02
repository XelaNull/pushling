# TODO: Horizontal Context Menu System for Touch Bar

**Status**: PLAN (not yet implemented)
**Created**: 2026-03-15
**Depends on**: Phase 6 (Interactivity) — Touch pipeline, GestureRecognizer, CreatureTouchHandler
**Affects**: Input/, Scene/, Creature/ subsystems

---

## Problem Statement

The Touch Bar Pushling currently has limited discoverable interactions. Users must know specific gesture types (double-tap for jump, triple-tap for easter eggs, drag for petting, etc.) with no visual affordance revealing what actions are available. There is no way to:

- See available actions for the creature at a glance
- Interact with world objects beyond tap/flick/pick-up
- Access utility actions (camera reset, weather, object placement) from the Touch Bar itself

We need a **horizontal context menu system** that:
1. Appears on long-press of any interactive element (creature, world objects, empty space)
2. Fits within the 30pt height constraint of the Touch Bar
3. Shows different menu items based on what was pressed
4. Supports slide-to-select (Touch Bar native interaction pattern)
5. Is a reusable system callable from anywhere in the codebase

### Long-Press Conflict Resolution

The long-press gesture is already used:
- **Creature**: Fires `look_at_touch` reflex (thought bubble) at 500ms
- **Object**: Fires `pickUp` at 500ms
- **World**: No current behavior

**Solution — Two-Phase Long-Press**:
- **Phase 1 (500ms)**: Existing behavior fires (thought bubble, pick-up highlight)
- **Phase 2 (800ms)**: If finger hasn't moved >5pt, Phase 1 crossfades into context menu
- **Movement gate**: If finger moves >5pt after Phase 1, it becomes a drag (existing behavior preserved)
- The thought bubble / pick-up highlight serves as a visual "preview" that transforms into the menu

---

## Design Goals

1. **Discoverable** — Users who hold their finger learn what's possible
2. **Touch Bar native** — Slide-to-select, horizontal layout, no vertical scrolling
3. **Non-intrusive** — Auto-dismiss on timeout, doesn't block breathing/animation
4. **Reusable** — Any subsystem can register context menus for any target type
5. **Performant** — <8 nodes total, no texture loading, stays within 16.6ms frame budget
6. **On-palette** — Uses only PushlingPalette colors (Void, Bone, Ash, Tide, Gilt)

---

## Visual Design

### Menu Item Sizing (30pt Bar Math)

```
Touch Bar height: 30pt
Menu item height: 24pt (Apple HIG minimum touch target)
Vertical padding:  3pt top + 3pt bottom = 6pt
Menu item width:  26pt (24pt icon area + 2pt horizontal gap)
Max items:         6 (26 * 6 = 156pt — comfortable in 1085pt width)
Typical items:     3-4 (78-104pt + background padding)
Background pad:    4pt each side = total menu width ~86-112pt for 3-4 items
```

### Color Scheme

| Element | Color | Alpha | Notes |
|---------|-------|-------|-------|
| Menu background | `Void` | 0.85 | Dark panel, OLED-friendly |
| Background border | `Ash` | 0.3 | Subtle edge definition |
| Item icon (normal) | `Bone` | 0.7 | Warm white, readable |
| Item icon (highlighted) | `Gilt` | 1.0 | Gold highlight on selection |
| Item label (normal) | `Bone` | 0.5 | Subtle text below icon |
| Item label (highlighted) | `Gilt` | 0.9 | Bright on selection |
| Highlight pill | `Ash` | 0.3 | Rounded rect behind selected item |
| Separator dots | `Ash` | 0.2 | Tiny dots between items |

### Font

- Item labels: `Menlo` 5pt (matches existing HUD style)
- Icons: SF Symbols rendered as `SKLabelNode` with `SFProText-Regular` or Unicode glyphs

### ASCII Art — Menu Appearance

```
Touch Bar (1085 x 30pt):
+---[====================================================================================]---+
|                                                                                             |  30pt
+---[====================================================================================]---+

Context menu on creature (4 items, centered at touch point):
+---[=============================[  Pet  Feed  Teach  Status  ]============================]---+
|                                  |__________________________|                                 |  30pt
|                                  |        ~104pt wide        |                                |
+---[==========================================================================================]---+

Close-up of the menu panel (not to scale vertically for readability):
 ___________________________
|  3pt padding               |
|  [icon] [icon] [icon] [icon]|  24pt touch targets
|   Pet   Feed  Teach  Status |  5pt labels (inside 24pt zone)
|  3pt padding               |
|____________________________|
        ~112pt wide

With highlight on "Feed":
 ___________________________
|                             |
|  [pet] [FEED] [tch] [sts]  |  "FEED" is Gilt, others are Bone
|   Pet  >Feed<  Teach Status |  Highlight pill behind "Feed"
|____________________________|

Actual pixel representation (30pt height, proportional):
. . . . . . . . . . ._________________________. . . . . . . . . . .
. . . . . . . . . . |  *    @    #    %  | . . . . . . . . . . .
. . . . . . . . . . | Pet  Feed Tch  Sts | . . . . . . . . . . .
. . . . . . . . . . |_____________________| . . . . . . . . . . .

Legend: * = paw icon, @ = fish icon, # = sparkle icon, % = heart icon
```

### Menu on World Object (3 items):

```
+---[===============[  Move  Remove  Inspect  ]================================================]---+
|                    |______________________|                                                       |
+---[==================================================================================]---+
```

### Menu on Empty Space (3 items):

```
+---[=================================[  Place  Weather  Reset  ]=============================]---+
|                                      |______________________|                                   |
+---[==================================================================================]---+
```

---

## Technical Architecture

### Core Types

```swift
// ContextMenuItem.swift — A single menu option

/// One item in a context menu.
struct ContextMenuItem {
    /// Unique identifier for this item.
    let id: String

    /// Display icon — Unicode glyph or SF Symbol name.
    /// Rendered as SKLabelNode text for zero-texture overhead.
    let icon: String

    /// Short label (max 6 characters recommended for 30pt bar).
    let label: String

    /// Whether this item is currently available (grayed out if false).
    var isEnabled: Bool = true

    /// Action callback when this item is selected.
    /// Receives the GestureTarget that was long-pressed.
    let action: (GestureTarget) -> Void
}

/// A complete context menu definition for a target.
struct ContextMenuDefinition {
    /// The items to display.
    let items: [ContextMenuItem]

    /// Optional title (not displayed — used for logging).
    let title: String
}
```

### Provider Protocol

```swift
// ContextMenuProvider.swift — Protocol for supplying menus

/// Implemented by subsystems that want to contribute context menu items.
/// The presenter queries providers when a long-press context menu is requested.
protocol ContextMenuProvider: AnyObject {
    /// Returns a menu definition for the given target, or nil if this
    /// provider has no menu for that target type.
    func contextMenu(for target: GestureTarget,
                     at position: CGPoint) -> ContextMenuDefinition?
}
```

### Presenter (Renderer + Input Handler)

```swift
// ContextMenuPresenter.swift — Renders and manages the context menu overlay

/// Manages context menu lifecycle: show, highlight, select, dismiss.
/// Owns the SKNode tree for the menu. Added to the scene at zPosition 600
/// (above HUD at 500, below debug at 1000).
final class ContextMenuPresenter {

    // MARK: - Configuration
    static let menuZPosition: CGFloat = 600
    static let itemWidth: CGFloat = 26
    static let itemHeight: CGFloat = 24
    static let paddingH: CGFloat = 4
    static let paddingV: CGFloat = 3
    static let iconFontSize: CGFloat = 10
    static let labelFontSize: CGFloat = 5
    static let animateInDuration: TimeInterval = 0.15
    static let animateOutDuration: TimeInterval = 0.1
    static let autoDismissTimeout: TimeInterval = 4.0
    static let highlightLerpSpeed: CGFloat = 0.3

    // MARK: - State
    private(set) var isVisible: Bool = false
    private var currentItems: [ContextMenuItem] = []
    private var currentTarget: GestureTarget = .world
    private var highlightedIndex: Int? = nil
    private var menuOriginX: CGFloat = 0
    private var autoDismissTimer: TimeInterval = 0

    // MARK: - Nodes
    private let rootNode: SKNode           // Container
    private let backgroundNode: SKShapeNode // Dark pill
    private let highlightNode: SKShapeNode  // Selection indicator
    private var itemNodes: [(icon: SKLabelNode, label: SKLabelNode)] = []

    // MARK: - Providers
    private var providers: [ContextMenuProvider] = []

    // MARK: - Callbacks
    var onDismiss: (() -> Void)?

    // MARK: - Public API
    func addToScene(_ scene: SKScene)
    func registerProvider(_ provider: ContextMenuProvider)
    func show(for target: GestureTarget, at position: CGPoint)
    func updateHighlight(at position: CGPoint)
    func selectHighlighted() -> Bool
    func dismiss(animated: Bool)
    func update(deltaTime: TimeInterval)

    // MARK: - Node Budget
    // rootNode(1) + background(1) + highlight(1) + items(2 each, max 6) = 15 max
    var nodeCount: Int { isVisible ? 3 + currentItems.count * 2 : 0 }
}
```

### Integration with Gesture System

```swift
// In GestureRecognizer.swift — new threshold constant:
static let contextMenuMinDuration: TimeInterval = 0.8  // Phase 2

// In GestureRecognizer.update() — after longPress fires at 500ms:
// At 800ms, fire a new .contextMenu gesture type if finger hasn't moved
```

```swift
// New gesture type:
enum GestureType {
    // ... existing ...
    case contextMenu  // NEW: fired at 800ms hold, <5pt movement
}
```

### Integration with CreatureTouchHandler

```swift
// In CreatureTouchHandler — new subsystem reference:
let contextMenuPresenter: ContextMenuPresenter

// In handleLongPress — existing behavior preserved (Phase 1)
// In handleContextMenu — NEW handler for Phase 2 long-press:
private func handleContextMenu(_ event: GestureEvent) {
    // Show context menu for the target
    contextMenuPresenter.show(for: event.target, at: event.position)
}

// In handleDrag — if context menu is visible, route to highlight update:
if contextMenuPresenter.isVisible {
    contextMenuPresenter.updateHighlight(at: event.position)
    return
}

// In handleTouchEnded — if context menu is visible, select + dismiss:
if contextMenuPresenter.isVisible {
    _ = contextMenuPresenter.selectHighlighted()
    contextMenuPresenter.dismiss(animated: true)
    return
}
```

---

## Animation Specifications

### Menu Appearance (show)

```
Duration: 0.15s
Easing:   easeOut

1. Background pill scales from 0.8 to 1.0 (X and Y)
2. Background pill fades from 0.0 to 0.85 alpha
3. Items fade in with 30ms stagger (left to right)
4. Items slide up 3pt (from y-2 to y+1) during fade
5. Subtle glow pulse on background border (Ash 0.3 -> 0.5 -> 0.3)
```

### Highlight Tracking (slide)

```
Duration: per-frame lerp
Speed:    0.3 lerp factor (smooth, not snappy)

1. Highlight pill (Ash at 0.3) lerps toward highlighted item position
2. Highlighted item icon color lerps Bone -> Gilt
3. Highlighted item label color lerps Bone(0.5) -> Gilt(0.9)
4. Previous highlight reverses: Gilt -> Bone
5. Highlight pill scales 1.0 -> 1.05 -> 1.0 on selection change
```

### Menu Dismissal (dismiss)

```
Duration: 0.1s (fast — don't block interaction)
Easing:   easeIn

1. All items fade out simultaneously
2. Background pill scales 1.0 -> 0.95
3. Background pill fades to 0.0
4. After complete: remove all child nodes, reset state
```

### Selection Confirmation (select)

```
Duration: 0.08s
Before dismiss:

1. Selected item flashes bright (Gilt at 1.0, scale 1.15)
2. Non-selected items fade to 0.0 immediately
3. Brief haptic-equivalent: selected item wiggles +-1pt X
4. Then standard dismiss animation
```

### Auto-Dismiss

```
Timeout: 4.0s after menu appears
Warning: At 3.5s, menu starts fading (alpha 1.0 -> 0.0 over 0.5s)
Cancel:  Any touch interaction resets the timeout
```

---

## Example Menu Definitions

### Creature Context Menu

```swift
ContextMenuDefinition(
    title: "Creature",
    items: [
        ContextMenuItem(id: "pet", icon: "\u{1F43E}", label: "Pet",
                        action: { _ in /* trigger petting mode */ }),
        ContextMenuItem(id: "feed", icon: "\u{1F41F}", label: "Feed",
                        action: { _ in /* open hand-feeding mode */ }),
        ContextMenuItem(id: "teach", icon: "\u{2728}", label: "Teach",
                        action: { _ in /* enter teach mode */ }),
        ContextMenuItem(id: "status", icon: "\u{2665}", label: "Status",
                        action: { _ in /* show HUD overlay */ }),
    ]
)
```

### World Object Context Menu

```swift
ContextMenuDefinition(
    title: "Object",
    items: [
        ContextMenuItem(id: "move", icon: "\u{270B}", label: "Move",
                        action: { target in /* enter pick-up mode */ }),
        ContextMenuItem(id: "remove", icon: "\u{2716}", label: "Remove",
                        action: { target in /* remove object from world */ }),
        ContextMenuItem(id: "inspect", icon: "\u{1F50D}", label: "Info",
                        action: { target in /* show object details */ }),
    ]
)
```

### Empty Space Context Menu

```swift
ContextMenuDefinition(
    title: "World",
    items: [
        ContextMenuItem(id: "place", icon: "\u{2795}", label: "Place",
                        action: { _ in /* enter object placement mode */ }),
        ContextMenuItem(id: "weather", icon: "\u{26C5}", label: "Weather",
                        action: { _ in /* cycle weather */ }),
        ContextMenuItem(id: "reset", icon: "\u{1F3AF}", label: "Reset",
                        action: { _ in /* reset camera */ }),
    ]
)
```

---

## Implementation Phases

### Phase 1: Core Data Types and Presenter Shell (Day 1)

- [ ] Create `ContextMenuItem` struct and `ContextMenuDefinition` struct
- [ ] Create `ContextMenuProvider` protocol
- [ ] Create `ContextMenuPresenter` class with node setup (no animation yet)
- [ ] Static `show()` that renders items at a position
- [ ] Static `dismiss()` that removes items
- [ ] Add to scene in `PushlingScene.setupHUD()`

### Phase 2: Gesture Integration (Day 1-2)

- [ ] Add `.contextMenu` case to `GestureType` enum
- [ ] Add `contextMenuMinDuration` threshold to `GestureRecognizer` (800ms)
- [ ] Fire `.contextMenu` event in `GestureRecognizer.update()` when:
  - Duration >= 800ms
  - Distance < 5pt
  - `longPressFiredForTouch` is already set (Phase 1 happened)
  - New guard: `contextMenuFiredForTouch` to prevent re-firing
- [ ] Add `handleContextMenu(_ event:)` to `CreatureTouchHandler`
- [ ] Route `.contextMenu` case in the gesture dispatch switch

### Phase 3: Long-Press Transition (Day 2)

- [ ] Modify `handleLongPress` to add a "pre-menu" visual hint:
  - Creature: thought bubble starts, tagged for potential transition
  - Object: pick-up highlight starts, tagged for potential transition
- [ ] When `.contextMenu` fires at 800ms:
  - Creature: crossfade thought bubble into context menu
  - Object: reverse pick-up animation, show context menu instead
  - World: show context menu directly (no Phase 1 for empty space)
- [ ] Movement gate: if drag is detected between 500-800ms, cancel menu
  - Set `activeDragTouchId` -> context menu won't fire
  - Existing drag behavior preserved

### Phase 4: Slide-to-Select Input (Day 2-3)

- [ ] In `handleDrag`: if `contextMenuPresenter.isVisible`, route to `updateHighlight(at:)`
- [ ] In `handleTouchEnded`: if menu is visible, call `selectHighlighted()` + `dismiss()`
- [ ] Highlight calculation:
  - Map touch X position to nearest menu item index
  - Each item has a 26pt-wide hit zone
  - Clamp to valid range [0, items.count - 1]
  - Dead zone: if touch is >30pt away from menu vertically, no highlight
- [ ] Per-frame lerp for smooth highlight pill movement
- [ ] Color transitions: Bone <-> Gilt lerp at 0.3 factor

### Phase 5: Animation Polish (Day 3)

- [ ] Implement show animation (scale + fade + stagger)
- [ ] Implement dismiss animation (scale + fade)
- [ ] Implement selection confirmation (flash + wiggle)
- [ ] Implement auto-dismiss with fade warning at 3.5s
- [ ] Implement highlight pill lerp (per-frame, smooth tracking)

### Phase 6: Menu Providers (Day 3-4)

- [ ] Create `CreatureMenuProvider` — provides creature context menu
  - Items gated by growth stage (e.g., "Teach" requires Critter+)
  - Items gated by state (e.g., "Feed" disabled if no pending commits)
- [ ] Create `ObjectMenuProvider` — provides world object context menu
  - Items vary by object type (e.g., "Water" for flower, "Throw" for ball)
- [ ] Create `WorldMenuProvider` — provides empty space context menu
  - Items gated by stage (e.g., "Place" requires Beast+)
- [ ] Register all providers in `GameCoordinator` wiring

### Phase 7: Action Wiring (Day 4)

- [ ] Wire creature menu actions:
  - "Pet" -> activate petting stroke mode
  - "Feed" -> activate hand-feeding mode with most recent commit
  - "Teach" -> send IPC event to trigger teach flow via MCP
  - "Status" -> show HUD overlay
- [ ] Wire object menu actions:
  - "Move" -> activate pick-up mode for the object
  - "Remove" -> remove object from world (with confirmation?)
  - "Info" -> show object details in HUD overlay
- [ ] Wire world menu actions:
  - "Place" -> enter object placement mode (future feature)
  - "Weather" -> cycle weather state
  - "Reset" -> reset camera to center on creature

### Phase 8: Edge Cases and Polish (Day 4-5)

- [ ] Menu clamping: ensure menu doesn't extend past scene edges (0-1085pt)
- [ ] Speech bubble conflict: dismiss active speech bubbles when menu opens
- [ ] Diamond indicator: dim diamond when menu is visible
- [ ] Sleeping creature: context menu shows "Wake" + "Status" only
- [ ] Mini-game active: suppress context menu during games
- [ ] Invitation active: suppress context menu during invitations
- [ ] Hatching ceremony: suppress context menu entirely

---

## File List with Estimated Line Counts

### New Files

| File | Location | Est. Lines | Purpose |
|------|----------|-----------|---------|
| `ContextMenuItem.swift` | `Input/` | ~45 | Data types: `ContextMenuItem`, `ContextMenuDefinition` |
| `ContextMenuProvider.swift` | `Input/` | ~20 | Protocol for menu providers |
| `ContextMenuPresenter.swift` | `Input/` | ~350 | Renderer, input handler, animation, lifecycle |
| `CreatureMenuProvider.swift` | `Input/` | ~80 | Creature-specific context menu items |
| `ObjectMenuProvider.swift` | `Input/` | ~90 | Object-specific context menu items |
| `WorldMenuProvider.swift` | `Input/` | ~60 | Empty-space context menu items |

**Total new code: ~645 lines across 6 files**

### Modified Files

| File | Location | Changes |
|------|----------|---------|
| `GestureRecognizer.swift` | `Input/` | Add `.contextMenu` gesture type, 800ms threshold, fire logic (~25 lines) |
| `CreatureTouchHandler.swift` | `Input/` | Add `contextMenuPresenter` property, `handleContextMenu()`, route drag/touchEnd to menu when visible (~40 lines) |
| `PushlingScene.swift` | `Scene/` | Add `contextMenuPresenter` setup in `setupHUD()` (~5 lines) |
| `GameCoordinator.swift` | `App/` | Create and wire `ContextMenuPresenter`, register providers (~15 lines) |

**Total modifications: ~85 lines across 4 files**

---

## Integration Points

### 1. Scene Graph (zPosition Hierarchy)

```
zPosition:
  1000  Debug overlay (existing)
   600  CONTEXT MENU (new) — above all UI, below debug
   500  HUD overlay (existing)
    45  Narration overlay (existing)
    40  Speech bubbles (existing)
    35  Particle effects (existing)
    15  Diamond indicator (existing)
    10  Creature (existing)
   0-5  World objects, terrain (existing)
```

### 2. Touch Event Flow (Modified)

```
TouchTracker
  -> GestureRecognizer
     -> 500ms: .longPress -> CreatureTouchHandler.handleLongPress()
                              (thought bubble / pick-up — existing)
     -> 800ms: .contextMenu -> CreatureTouchHandler.handleContextMenu()
                                -> ContextMenuPresenter.show()
     -> drag while menu visible:
                              -> ContextMenuPresenter.updateHighlight()
     -> touch ended while menu visible:
                              -> ContextMenuPresenter.selectHighlighted()
                              -> ContextMenuPresenter.dismiss()
```

### 3. GameCoordinator Wiring

```swift
// In GameCoordinator.init():
let contextMenuPresenter = ContextMenuPresenter()
contextMenuPresenter.addToScene(scene)

// Register providers
let creatureMenuProvider = CreatureMenuProvider(
    touchHandler: creatureTouchHandler,
    emotionalState: emotionalState,
    stage: creatureStage
)
let objectMenuProvider = ObjectMenuProvider(
    objectInteraction: objectInteraction
)
let worldMenuProvider = WorldMenuProvider(
    cameraController: scene.cameraController
)

contextMenuPresenter.registerProvider(creatureMenuProvider)
contextMenuPresenter.registerProvider(objectMenuProvider)
contextMenuPresenter.registerProvider(worldMenuProvider)

// Wire to touch handler
creatureTouchHandler.contextMenuPresenter = contextMenuPresenter
```

### 4. Suppression Conditions

The context menu should NOT appear when:

```swift
func shouldSuppressContextMenu() -> Bool {
    return scene.isHatching           // Hatching ceremony active
        || miniGameManager.isGameActive // Mini-game in progress
        || invitationSystem.activeInvitation?.state == .offered  // Invitation pending
        || contextMenuPresenter.isVisible  // Menu already showing
}
```

### 5. Accessibility / MCP Integration

The context menu is a human-only interaction. Claude's MCP tools provide the same actions programmatically:
- `pushling_move` = "Move" object action
- `pushling_speak` = not in context menu (Claude speaks, human doesn't)
- `pushling_teach` = "Teach" creature action
- `pushling_world("create")` = "Place" world action
- `pushling_nurture` = not in context menu (MCP-only)

The context menu gives the human direct access to actions that would otherwise require knowing specific gestures or using Claude as an intermediary.

---

## Node Budget Impact

| State | Nodes Added | Total Budget |
|-------|------------|-------------|
| Menu hidden | 0 | No impact |
| Menu visible (4 items) | 12 | rootNode(1) + bg(1) + highlight(1) + 4x(icon+label) + border(1) |
| Menu visible (6 items) | 16 | rootNode(1) + bg(1) + highlight(1) + 6x(icon+label) + border(1) |

At peak (6-item menu): 16 nodes added temporarily. Well within the 120-node budget, especially since the menu replaces/hides other UI (thought bubble, pick-up shadow).

---

## Performance Considerations

1. **No texture loading**: All icons are Unicode glyphs rendered as SKLabelNode text
2. **Pre-allocated nodes**: The presenter pre-creates 6 item slots; unused ones are hidden
3. **Per-frame cost**: Only when visible — highlight lerp is 2 multiplies + 2 adds per frame
4. **SKAction-free animation**: All animation is per-frame manual (like DiamondIndicator), avoiding SKAction allocation overhead
5. **Menu show/dismiss**: SKShapeNode path creation happens once at setup; show/dismiss only toggle visibility and alpha

---

## Open Questions

1. **Haptic feedback**: Touch Bar supports `NSHapticFeedbackManager`. Should we add a subtle haptic on menu appear and item selection?
2. **Sound effects**: Should the menu have a quiet "pop" sound on appear? A "click" on select?
3. **Dynamic items**: Should providers be re-queried each time the menu opens, or cached? (Recommendation: re-query each time — provider can cache internally if needed)
4. **Nested menus**: Not planned for v1. If "Place" needs a sub-menu of object types, that's a separate design challenge. For now, "Place" enters a placement mode.
5. **Menu during sleep**: Should the sleeping creature's context menu include "Wake" which triggers the nose-boop wake sequence? Or should the long-press wake behavior take priority?

---

## Success Criteria

- [ ] Long-press on creature shows context menu with 4 items after 800ms
- [ ] Long-press on world object shows context menu with 3 items after 800ms
- [ ] Long-press on empty space shows context menu with 3 items after 800ms
- [ ] Slide-to-select highlights items with smooth Gilt color transition
- [ ] Lifting finger selects the highlighted item and triggers its action
- [ ] Menu auto-dismisses after 4 seconds of no interaction
- [ ] Existing long-press behaviors (thought bubble at 500ms, pick-up at 500ms) still work
- [ ] Movement after 500ms long-press enters drag mode, not context menu
- [ ] Menu is suppressed during hatching, mini-games, and active invitations
- [ ] Total node count stays under 120 with menu visible
- [ ] Frame time stays under 16.6ms with menu visible
- [ ] Menu clamps to scene bounds (doesn't extend past 0 or 1085pt)
## UX Alternatives & Interaction Patterns

### Hardware Constraints Recap

Before evaluating patterns, the non-negotiable constraints:

| Constraint | Value | Impact |
|-----------|-------|--------|
| Touch Bar height | 30 points (60px @2x) | Cannot stack UI vertically. One row only. |
| Touch Bar width | 1085 points (2170px @2x) | Generous horizontal space |
| Touch precision | Sub-pixel float, 60Hz | Smooth tracking, no force/pressure |
| Force/Pressure | **NONE** — purely capacitive | No "press harder" mechanics |
| Multi-touch | 2-3 practical simultaneous | Strip width limits practical touches |
| OLED | True blacks, P3 gamut | Items on black = invisible until lit |
| Frame budget | 16.6ms at 60fps (~5.7ms used) | ~11ms headroom for menu rendering |
| Existing long-press | 500ms on creature = examine/thought bubble | Menu trigger must not conflict |
| Existing long-press | 500ms on object = pick up & move | Object long-press is taken |

**The fundamental truth**: 30 points of height means every menu pattern is effectively **one-dimensional**. Vertical arrangement is impossible for readable, tappable items. All patterns must be horizontal or use creative workarounds.

---

### Pattern 1: Horizontal Strip Menu

**Concept**: Long-press triggers a horizontal strip of options that slides in from the edges or expands from the press point, occupying a band within the 30pt height.

#### ASCII Mockup

```
Before (normal scene):
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ   ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘
                  ↑ long-press here

After (menu appears, creature stays):
┌─────────────────────────────────────────────────────────────┐
│  ·  ╭─────╮╭─────╮╭─────╮╭─────╮╭─────╮  ·    ·    ·    · │
│     │ 🐾  ││ 💤  ││ 🗣️  ││ 🎲  ││  ❌ │  ᓚᘏᗢ              │ 30pt
│  ·  ╰─────╯╰─────╯╰─────╯╰─────╯╰─────╯  ·    ·    ·    · │
└─────────────────────────────────────────────────────────────┘
       Pet    Sleep  Speak   Play   Close

Alternative — slim version (items are 20pt tall, 6pt margin):
┌─────────────────────────────────────────────────────────────┐
│····[🐾 Pet][💤 Nap][🗣️ Talk][🎲 Play][❌]····ᓚᘏᗢ···········│ 30pt
└─────────────────────────────────────────────────────────────┘
```

#### Interaction Flow

1. Long-press (500ms) on creature or empty space triggers menu
2. Items slide in horizontally from the long-press point outward (left and right)
3. **Slide-to-select** (recommended): finger stays down from long-press, slides to desired option, lifts to confirm
4. **Alternative — tap-to-select**: finger lifts after menu appears, then tap an option
5. Selected item highlights (brightness pulse), then menu dismisses

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **5-7** (each item ~60-80pt wide with icon + 3-4 char label = ~400-560pt) |
| Vertical fit | Good — items are full 30pt height, single row |
| Animation cost | Low: 5-7 SKLabelNode + SKShapeNode background per item (~14 nodes). Slide-in animation via SKAction.moveTo. <1ms render. |
| Dismissal | Timeout (3s), tap outside items, swipe away, or select |
| Gesture conflict | **Moderate** — long-press on creature currently triggers thought bubble. Need to differentiate: long-press + hold = menu, long-press + release = thought bubble. Or use a different trigger entirely. |
| Creature visibility | **Partial** — creature stays visible but world behind menu items is obscured |
| Discoverability | Low — user must know to long-press. Need subtle affordance. |
| Touch target size | Each item is 60-80pt wide x 30pt tall = comfortable touch targets |

#### Slide-to-Select vs Tap-to-Select

| Variant | Pros | Cons |
|---------|------|------|
| **Slide-to-select** | Faster (one continuous gesture), more fluid, proven pattern (iOS context menus) | Requires finger to stay down, harder for items far from press point, accidental selection risk |
| **Tap-to-select** | More deliberate, can browse first, works for distant items | Two-step interaction (longer), menu must stay visible longer, needs explicit dismiss |

**Recommendation**: Slide-to-select with tap-to-select as fallback. If finger lifts without selecting, menu stays open for 3 seconds for tap selection.

#### Strengths

- Natural fit for the horizontal strip form factor
- Familiar pattern (resembles toolbar / tab bar)
- Each item has enough space for an icon + short label
- Creature remains visible alongside the menu
- Low animation cost

#### Weaknesses

- 5-7 item limit may not be enough for all contexts
- Overlaps world view — the living scene is partially hidden
- Long-press trigger conflicts with existing gestures on objects/creature

---

### Pattern 2: Replace Scene (Full Takeover)

**Concept**: Long-press causes the creature and world to slide off-screen, replaced by a full-width menu that uses all 1085 points. After selection (or dismissal), the scene slides back.

#### ASCII Mockup

```
Before:
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ   ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘

Transition (scene slides left, menu slides in from right, 200ms):
┌─────────────────────────────────────────────────────────────┐
│ᘏᗢ ·  🪨  ·  · │ 🐾 Pet │ 💤 Nap │ 🗣️ Talk │ 🎲 Play │ ❓ │ 30pt
└─────────────────────────────────────────────────────────────┘

Fully open:
┌─────────────────────────────────────────────────────────────┐
│ ◀ │ 🐾 Pet │ 💤 Nap │ 🗣️ Talk │ 🎲 Play │ 📊 Stats │ ⚙️  │ 30pt
└─────────────────────────────────────────────────────────────┘
  ↑ back button                                          settings

With submenu (creature-initiated action submenu):
┌─────────────────────────────────────────────────────────────┐
│ ◀ │ 🎲 Catch │ 🧠 Memory │ 🗺️ Hunt │ 🎵 Rhythm │ 💪 Tug  │ 30pt
└─────────────────────────────────────────────────────────────┘
  ↑ back to main menu
```

#### Interaction Flow

1. Long-press (500ms) triggers the transition
2. Scene slides left over 200ms, menu slides in from right
3. Tap any menu item to select
4. Tap "◀" (back) or swipe right to dismiss and restore scene
5. Scene slides back in over 200ms

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **8-12** per level (each item ~80-120pt, full 1085pt available) |
| Vertical fit | Perfect — uses entire strip for menu items |
| Animation cost | Medium: scene slide-out (1 parent node transform), menu items (8-12 nodes), slide-in (1 parent node transform). ~20 nodes total. Transition takes 200ms = 12 frames of animation. |
| Dismissal | Back button, swipe right, timeout (5s idle), or selection |
| Gesture conflict | Low — long-press clearly enters a "menu mode" that's visually distinct |
| Creature visibility | **None** — creature is off-screen during menu. Breaks "always alive" principle. |
| Discoverability | Low — same long-press discovery problem as Pattern 1 |
| Touch target size | Large — each item is 80-120pt wide x 30pt tall |

#### Strengths

- Maximum item capacity (8-12 per level)
- Supports nested submenus naturally (slide left for deeper, back button returns)
- Clear visual state change — user knows they're in "menu mode"
- No overlap issues — clean, readable layout
- Touch targets are generous and unambiguous
- Room for text labels alongside icons

#### Weaknesses

- **Breaks creature aliveness** — the creature disappears entirely during menu use. This violates the core design principle that the creature is always visible and always breathing.
- Transition animation adds 400ms round-trip latency (200ms in + 200ms out)
- Context is lost — user can't see what they're acting on while choosing
- Feels like a mode switch rather than a contextual interaction
- Jarring if used frequently

#### Mitigation for Aliveness

- Tiny creature silhouette in the "◀" back button (creature peeks from the edge, breathing animation continues at reduced scale)
- Menu items could subtly breathe (very slight Y-scale sine wave, 1.01x, to maintain organic feel)
- Quick transition (200ms) minimizes time without creature

---

### Pattern 3: Scroll Wheel (Single-Slot Carousel)

**Concept**: Long-press opens a single display slot at the press point. Swipe left/right cycles through options in that slot. Release on desired option to select.

#### ASCII Mockup

```
Before:
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ   ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘

Menu open (single slot at press point, creature dimmed):
┌─────────────────────────────────────────────────────────────┐
│  ·   ·    ·  ᓚ  ╭──────────╮  ·    ·   ·    ·    ·    ·   │
│               ᘏ  │ 🐾 Pet   │                              │ 30pt
│               ᗢ  ╰──────────╯                              │
└─────────────────────────────────────────────────────────────┘
                    ← swipe → to cycle

After swiping right:
┌─────────────────────────────────────────────────────────────┐
│  ·   ·    ·  ᓚ  ╭──────────╮  ·    ·   ·    ·    ·    ·   │
│               ᘏ  │ 💤 Nap   │                              │ 30pt
│               ᗢ  ╰──────────╯                              │
└─────────────────────────────────────────────────────────────┘

With peek (adjacent items partially visible):
┌─────────────────────────────────────────────────────────────┐
│  ·   ·   ᓚᘏ ·╌╌╌╭──────────╮╌╌╌·  ·    ·    ·    ·    ·  │
│              🐾  │ 💤 Nap   │ 🗣️                           │ 30pt
│              ᗢ·╌╌╌╰──────────╯╌╌╌·                         │
└─────────────────────────────────────────────────────────────┘
            prev     current     next (faded)
```

#### Interaction Flow

1. Long-press (500ms) opens the scroll slot near press point
2. Slide left/right to cycle through options (items snap into slot)
3. Lift finger on desired option to select
4. Or: after opening, swipe gestures cycle, tap the slot to confirm current item

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **Unlimited** (only one visible at a time, cycle through any number) |
| Vertical fit | Perfect — single slot fills 30pt height |
| Animation cost | Very low: 1 active label node + 2 peek nodes (faded) + background shape = ~5 nodes. Snap animation is a single SKAction.moveTo. |
| Dismissal | Timeout (3s after last swipe), tap outside slot, or selection |
| Gesture conflict | **High** — swipe conflicts with camera pan / laser pointer / world interaction. Must gate by menu-open state. |
| Creature visibility | Good — creature remains visible, only small area obscured |
| Discoverability | Very low — both the trigger and the swipe-to-cycle mechanic are hidden |
| Touch target size | The slot itself: ~100pt wide x 30pt tall = decent |

#### Strengths

- Minimal screen real estate — only one slot width occupied
- Handles any number of options (no upper limit)
- Creature stays visible and alive
- Extremely low node count (~5 nodes)
- Elegant, minimal aesthetic fits the OLED aesthetic

#### Weaknesses

- **Slow for many items** — cycling through 8 options one by one takes 8 swipe gestures
- No overview — user can't see all options at once; must memorize or discover by cycling
- Swipe-to-cycle conflicts with existing horizontal swipe gestures
- Peek items at edges are hard to read at 30pt height
- Not suitable for frequent use — too slow for common actions
- Double-hidden: the trigger is hidden AND the navigation mechanic is hidden

---

### Pattern 4: Expanding Bubble

**Concept**: Long-press on creature causes a bubble to expand from the press point, with options arranged in an arc or fan above/around the creature.

#### ASCII Mockup

```
Before:
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ   ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘

Expanding bubble (creature at center, options fan out):
┌─────────────────────────────────────────────────────────────┐
│  ·  🐾   💤   ᓚᘏᗢ   🗣️   🎲  ·    ·    ·    ·    ·    ·  │ 30pt
└─────────────────────────────────────────────────────────────┘
       ↑     ↑    ↑     ↑     ↑
      items fan out from creature center

With arc emphasis (items arc slightly, icons only):
┌─────────────────────────────────────────────────────────────┐
│  · 🐾  💤  ᓚ̈ᘏᗢ  🗣️  🎲 ·    ·    ·    ·    ·    ·    ·   │ 30pt
└─────────────────────────────────────────────────────────────┘
      ↑   ↑   ↑   ↑   ↑
   Items are vertically offset by ±2-3pt to suggest an arc

With glow rings (OLED effect):
┌─────────────────────────────────────────────────────────────┐
│  · ◌🐾◌ ◌💤◌ ᓚᘏᗢ ◌🗣️◌ ◌🎲◌  ·    ·    ·    ·    ·    · │ 30pt
└─────────────────────────────────────────────────────────────┘
     glow   glow  creature  glow   glow
```

#### Interaction Flow

1. Long-press (500ms) on creature begins expansion
2. Options expand outward from creature center over 200ms
3. World behind options dims slightly (overlay at 30% opacity)
4. Slide to an option (finger still down from long-press) or lift and tap
5. Selected option pulses bright, then all options contract back to creature over 150ms
6. Action executes after menu dismisses

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **4-6** (space on either side of creature, ~50pt per icon with glow ring) |
| Vertical fit | Marginal — arc effect is barely perceptible at 30pt. Options are essentially in a line with ±2-3pt vertical offset. The "arc" is more conceptual than visible. |
| Animation cost | Medium: 4-6 icon nodes + 4-6 glow ring nodes + dimmer overlay = ~13 nodes. Expand/contract animations via SKAction.scale + move. |
| Dismissal | Timeout (3s), tap outside options, or selection |
| Gesture conflict | Same as Pattern 1 — long-press on creature conflicts |
| Creature visibility | **Good** — creature is at the center of the fan, visible and alive |
| Discoverability | Low — long-press trigger is hidden |
| Touch target size | Small — icons are ~15-20pt diameter circles. Below ideal touch target size. |

#### Strengths

- Creature-centric — feels like the creature is presenting options
- Visual polish potential with OLED glow rings (bright circles on true black)
- Compact footprint — doesn't take over the whole bar
- Creature remains at center, breathing, alive
- Beautiful expand/contract animation

#### Weaknesses

- **Only 4-6 items max** — fewer than horizontal strip
- Touch targets are small circles (~15-20pt) — fat finger problem on the narrow strip
- The "arc" is nearly invisible at 30pt height — essentially a horizontal row with pretension
- Icons-only (no room for text labels) — less accessible
- If creature is near edge of bar, items would be clipped — needs edge handling

#### OLED-Specific Opportunities

The glow ring effect is uniquely beautiful on the Touch Bar's OLED:
- True black surround makes small light sources pop
- P3 color gamut allows vivid, saturated glow colors
- Each option's glow could be color-coded (warm = action, cool = information, etc.)
- Glow intensity could pulse slowly (alive, organic, matching creature breathing)

---

### Pattern 5: Radial Menu (Semi-Circle)

**Concept**: Long-press opens a semi-circle of options centered on the press point, with items arranged in an arc above (or around) the touch.

#### ASCII Mockup — The Problem

```
A true semi-circle at 30pt height:

Full semi-circle (radius 15pt, centered at Y=15):
┌─────────────────────────────────────────────────────────────┐
│                        🎲                                   │
│                    💤       🗣️                               │ 30pt
│                  🐾    ×    ⚙️                               │
└─────────────────────────────────────────────────────────────┘
                       ↑ press point

The problem: at radius 15pt, items at the top of the arc are only
15pt from items at the sides. Touch targets overlap. And the
entire arc fits in a ~30x30pt square — everything is cramped.
```

```
Wider, flatter arc (radius 60pt, only upper arc used):
┌─────────────────────────────────────────────────────────────┐
│        🐾      💤      ×      🗣️      🎲                    │ 30pt
└─────────────────────────────────────────────────────────────┘
         ↑       ↑      ↑       ↑       ↑
     At this radius, items are essentially in a line.
     The "radial" aspect is a visual lie.
```

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **3-5** (semi-circle is tiny at 30pt) |
| Vertical fit | **POOR** — a 30pt height semi-circle has a 15pt radius. Items at different arc positions are too close together to distinguish by touch. |
| Animation cost | Medium: 4-5 nodes arranged on arc + connection lines. ~10 nodes. |
| Dismissal | Slide-to-select (standard radial menu pattern) |
| Gesture conflict | Same long-press conflict |
| Creature visibility | Depends on placement — items may overlay creature |
| Discoverability | Low |
| Touch target size | **POOR** — items at different arc positions are only 8-12pt apart vertically |

#### The Honest Assessment

A radial menu is fundamentally a 2D interaction pattern being forced into an effectively 1D space. At 30pt height:

- A semi-circle with radius 15pt (maximum that fits) has items crammed into a 30x15pt area
- Items on the arc are as close as 8pt apart — below the minimum for reliable touch discrimination
- To make items touchable, the radius must increase to ~60pt, at which point the arc is so flat it's indistinguishable from a horizontal line
- The entire raison d'etre of a radial menu (equal angular distance to all items from center) is meaningless when the angular range is compressed to ~30 degrees

**Verdict: Not recommended.** A radial menu on a 30pt-tall strip is a horizontal strip with extra math and no benefit. If the visual language of "radiating from a point" is desired, Pattern 4 (Expanding Bubble) achieves the same emotional effect with better practical usability.

---

### Pattern 6: Creature-Presented Menu (Recommended Hybrid)

**Concept**: The creature itself becomes the menu interface. Long-press causes the creature to sit up, and speech-bubble-style options emerge from the creature — combining the expanding bubble's aesthetics with the horizontal strip's practicality. The creature is visibly "showing you" the options.

This pattern treats the creature as a living interface element rather than something that gets obscured by UI.

#### ASCII Mockup

```
Before:
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ   ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘

After long-press (creature sits up, options emerge like speech):
┌─────────────────────────────────────────────────────────────┐
│  ·  [ Pet ][ Nap ]  ᓚᘏᗢ  [ Talk ][ Play ]  ·    ·    ·   │ 30pt
└─────────────────────────────────────────────────────────────┘
       ←─ options ─→  sitting  ←─ options ─→
                       up, ears
                       alert

Creature near left edge (options shift right):
┌─────────────────────────────────────────────────────────────┐
│ᓚᘏᗢ  [ Pet ][ Nap ][ Talk ][ Play ][ Stats ] ·    ·    ·  │ 30pt
└─────────────────────────────────────────────────────────────┘
  ↑     ←──── all options to the right ────→
  creature turns to face options

Creature near right edge (options shift left):
┌─────────────────────────────────────────────────────────────┐
│  ·  ·  [ Stats ][ Play ][ Talk ][ Nap ][ Pet ]  ᓚᘏᗢ      │ 30pt
└─────────────────────────────────────────────────────────────┘
          ←──── all options to the left ────→    ↑ faces left

With category icons (icon-only for compact mode):
┌─────────────────────────────────────────────────────────────┐
│  ·   [🐾] [💤] [🗣️]  ᓚᘏᗢ  [🎲] [📊] [⚙️]   ·    ·    · │ 30pt
└─────────────────────────────────────────────────────────────┘

Selected state (option highlights, creature reacts):
┌─────────────────────────────────────────────────────────────┐
│  ·  [ Pet ][ Nap ]  ᓚᘏᗢ  [▸Talk◂][ Play ]  ·    ·    ·   │ 30pt
└─────────────────────────────────────────────────────────────┘
                       ↑ ears perk toward selected option
```

#### Interaction Flow

1. Long-press (500ms) on creature — creature enters "presenting" pose (sits up straight, ears alert, tail wraps)
2. Options emerge from the creature outward over 200ms, splitting left/right (or all one side near edges)
3. World dims to 60% brightness behind options (OLED: truly darker, not just overlaid)
4. **Slide-to-select**: Finger slides from creature to desired option. Creature's gaze follows finger.
5. **Hover feedback**: As finger hovers over each option, creature reacts (ears tilt toward it, slight lean)
6. **Confirm**: Lift finger on option. Option pulses Gilt, creature nods, options retract back to creature over 150ms.
7. **Cancel**: Lift finger on creature (center) or outside all options. Creature shrugs, options retract.

#### Evaluation

| Criterion | Assessment |
|-----------|-----------|
| Max items | **6-8** (3-4 per side of creature, or up to 8 on one side near edges) |
| Vertical fit | Good — options are full 30pt height |
| Animation cost | Medium: 6-8 option nodes (label + background = 2 each) + dim overlay + creature pose change = ~18 nodes max. All within budget. |
| Dismissal | Select, cancel (lift on creature/outside), timeout 3s, or swipe away |
| Gesture conflict | Moderate — shares long-press trigger with thought bubble. See disambiguation below. |
| Creature visibility | **Excellent** — creature is central, visibly participating in the interaction |
| Discoverability | Low-medium — but creature's "presenting" pose makes it obvious what to do once triggered |
| Touch target size | Each option: ~60-80pt wide x 30pt tall = comfortable |

#### Creature Reactions During Menu

This is what makes this pattern special — the creature is alive throughout:

| User Action | Creature Reaction |
|------------|-------------------|
| Finger hovers over "Pet" | Creature leans toward that side, eyes half-close expectantly |
| Finger hovers over "Play" | Ears perk up, tail uncurls, alert posture |
| Finger hovers over "Nap" | Slight yawn, eyes droop |
| Finger hovers over "Talk" | Mouth opens slightly, ear tilts |
| Finger moves away from all options | Creature looks at finger, slight head tilt (confused) |
| Finger returns to creature (cancel) | Creature blinks, shrugs, resumes prior behavior |
| Timeout with no selection | Creature yawns, options dissolve, returns to idle |

#### Strengths

- **Creature stays alive and participates** — aligns with "creature IS the interface" principle
- Natural metaphor: creature is "showing you what it can do"
- Creature reactions make the menu feel organic rather than mechanical
- Handles 6-8 items comfortably
- Edge-aware layout (all items shift to available side)
- Slide-to-select is fast (single continuous gesture)

#### Weaknesses

- Requires custom creature animations for the "presenting" pose
- Creature-centered only — doesn't work for world-context menus (different pattern needed for objects/terrain)
- The creature reaction system adds animation complexity
- Still requires affordance for long-press discoverability

---

### Pattern Comparison Matrix

| Criterion | Strip | Replace Scene | Scroll Wheel | Expanding Bubble | Radial | Creature-Presented |
|-----------|-------|--------------|--------------|-----------------|--------|-------------------|
| Max items | 5-7 | 8-12 | Unlimited | 4-6 | 3-5 | 6-8 |
| Creature alive? | Partial | **No** | Yes | Yes (center) | Partial | **Yes (active)** |
| Vertical fit | Good | Perfect | Perfect | Marginal | **Poor** | Good |
| Node count | ~14 | ~20 | ~5 | ~13 | ~10 | ~18 |
| Touch targets | Good | Large | Good | Small | **Poor** | Good |
| Submenus? | Awkward | Natural | No | No | No | Via replacement |
| Speed to select | Fast | Medium | **Slow** | Fast | Fast | Fast |
| Edge handling | Clips | N/A | OK | Clips | Clips | Adaptive |
| Gesture conflict | Moderate | Low | High | Moderate | Moderate | Moderate |
| Visual polish | Medium | Low | Low | **High** | Low | **High** |
| Aliveness score | 4/10 | 1/10 | 6/10 | 7/10 | 3/10 | **9/10** |

---

### Recommended Architecture: Dual-Pattern System

No single pattern serves all contexts. The recommendation is a two-pattern system:

| Context | Pattern | Why |
|---------|---------|-----|
| **Creature menu** (long-press on creature) | **Creature-Presented** (Pattern 6) | Creature participates, natural metaphor, good item capacity |
| **World/system menu** (long-press on empty space, or via 3-finger tap) | **Horizontal Strip** (Pattern 1) or **Replace Scene** (Pattern 2) | No creature to center on, needs different visual language |

For the world/system menu: Pattern 1 (Horizontal Strip) is preferred over Pattern 2 (Replace Scene) because it preserves creature visibility. Pattern 2 should be reserved for deep settings/configuration screens where 12+ items are needed.

---

### Long-Press Trigger Disambiguation

The long-press gesture (500ms) is already used for:
- On creature: thought bubble / examine
- On object: pick up & move

Three disambiguation approaches:

#### Approach A: Duration-Based (Recommended)

| Duration | Action |
|----------|--------|
| 500ms - 800ms + release | Original behavior (thought bubble / pick up) |
| 800ms+ (hold continues) | Menu opens |

The user's intention is distinguished by whether they release after long-press recognition or continue holding. 800ms is long enough to feel intentional but short enough not to be tedious.

**Implementation**: At 500ms, show a subtle "loading ring" indicator (thin arc that fills from 0 to 360 degrees over 300ms). If the user keeps holding until the ring completes (800ms total), the menu opens. If they release before the ring completes, the original long-press action fires.

```
500ms mark — long press recognized, ring begins:
┌─────────────────────────────────────────────────────────────┐
│  🌿  ·    ·  ᓚᘏᗢ◠  ·  🪨     ·    ·   🌱   ·    ·  🌿   │ 30pt
└─────────────────────────────────────────────────────────────┘
               ↑ tiny arc indicator appears

800ms mark — ring complete, menu expands:
┌─────────────────────────────────────────────────────────────┐
│  ·  [ Pet ][ Nap ]  ᓚᘏᗢ  [ Talk ][ Play ]  ·    ·    ·   │ 30pt
└─────────────────────────────────────────────────────────────┘
```

#### Approach B: Target-Based

| Target | Long-Press Action |
|--------|-------------------|
| On creature body | Menu (creature-presented) |
| On creature head/nose | Thought bubble (original) |
| On object | Pick up (original, no menu) |
| On empty space | World menu (horizontal strip) |

Split the creature hitbox into regions: head region triggers the original behavior, body region triggers the menu. This is fragile at the creature's small sizes (6-25pt wide) and is not recommended.

#### Approach C: Gesture Modifier

Use a distinct gesture for the menu, freeing long-press for its original use:

| Gesture | Action |
|---------|--------|
| Long-press | Original behavior (thought bubble / pick up) |
| **Double-tap then hold** (tap + 200ms + hold 500ms) | Menu opens |
| **Two-finger tap** (on creature) | Menu opens |

This avoids all conflicts but introduces a less discoverable trigger. The double-tap-then-hold is used by iOS for text selection and may feel natural to some users.

**Recommendation**: Approach A (duration-based) for simplicity and discoverability. The loading ring indicator makes the mechanic self-teaching: users who accidentally hold too long will discover the menu, and the ring teaches them the timing for next time.

---

### Affordance: Indicating Menu Availability

The user needs to know that long-pressing will reveal a menu. Affordance options:

#### Option 1: Subtle Pulse on Idle (Recommended)

After the creature has been idle for 30+ seconds with no interaction, a very subtle "invitation pulse" plays:
- Creature's outline brightens by 10% for 0.5s, then fades back
- Happens at most once per 5 minutes
- If the user has never opened the menu, the pulse frequency increases (once per 2 minutes for the first week)
- First-time trigger: the loading ring animates autonomously once as a hint, then fades

#### Option 2: First-Touch Tutorial

At the `first_touch` milestone (1 total touch), the tutorial overlay that already teaches tap/double-tap/long-press adds a fourth panel:

```
┌─────────────────────────────────────────────────────────────┐
│  Tap = Pet  ·  2×Tap = Play  ·  Hold = Think  · Hold+ = ⋯ │ 30pt
└─────────────────────────────────────────────────────────────┘
```

The "Hold+ = ..." hint is deliberately mysterious, encouraging exploration.

#### Option 3: Creature Invitation

At Beast+ stage (when the creature can speak), the creature occasionally says `"hold me..."` or `"ask me..."` as a hint. At earlier stages, the creature mimics the gesture: it sits up in the "presenting" pose briefly during idle, then relaxes — demonstrating what the menu looks like without the user triggering it.

**Recommendation**: All three, layered:
1. Tutorial at first touch (immediate)
2. Creature self-demo during idle (ongoing, subtle)
3. Verbal hints at Beast+ (later game)

---

### Nested Submenus

For contexts requiring more than 6-8 items, nested submenus are needed. Two approaches:

#### Approach A: Lateral Slide (Recommended)

Selecting a category item causes the current menu to slide left, and a submenu slides in from the right. A "◀" back item appears at the left edge.

```
Main menu:
┌─────────────────────────────────────────────────────────────┐
│  ·  [ Pet ][ Nap ]  ᓚᘏᗢ  [▸Games▸][ Stats ]  ·    ·    · │ 30pt
└─────────────────────────────────────────────────────────────┘
                              ↑ "▸" indicators show this has a submenu

User selects "Games" → slides to submenu:
┌─────────────────────────────────────────────────────────────┐
│  [◀]  [ Catch ][ Memory ]  ᓚᘏᗢ  [ Hunt ][ Rhythm ] · ·   │ 30pt
└─────────────────────────────────────────────────────────────┘
   ↑ back                    creature stays centered
```

- Maximum 2 levels deep (main → sub). No sub-sub-menus.
- Transition: 150ms slide animation
- Back button returns to main menu with reverse slide
- Category items have subtle "▸" indicators showing they expand

#### Approach B: Replace-in-Place

Category selection replaces all items with submenu items instantly (no slide animation). A "◀" back item appears. Simpler to implement, less visually polished.

**Recommendation**: Approach A (lateral slide). The animation makes the hierarchy clear and the transition feels natural. Limit to 2 levels.

---

### Accessibility Considerations

#### Touch Target Sizing

| Pattern | Item Size | Apple HIG (44pt min) | Assessment |
|---------|-----------|---------------------|-----------|
| Horizontal Strip | 60-80pt x 30pt | Width OK, height below | Acceptable — Touch Bar apps routinely use 30pt targets |
| Replace Scene | 80-120pt x 30pt | Width OK, height below | Good |
| Scroll Wheel | 100pt x 30pt | OK | Good |
| Expanding Bubble | 15-20pt diameter | **Far below** | **Poor** — needs larger hit zones |
| Creature-Presented | 60-80pt x 30pt | Width OK, height below | Acceptable |

All Touch Bar interactions inherently violate the 44pt minimum height guideline. This is an accepted limitation of the platform — Apple's own Touch Bar buttons are 30pt tall.

For the expanding bubble pattern, invisible hit zones should extend 10pt beyond the visible icon to create effective 30-40pt touch targets.

#### Visual Contrast

- Menu item backgrounds: Ash (#2A2A2A) or subtle dark gradient on OLED black
- Text: Bone (#E8E0D4) on Ash background = high contrast
- Selected state: Gilt (#D4A843) highlight with increased brightness
- Disabled items: 40% opacity (dimmed but visible structure)
- All colors from the established P3 palette

#### Screen Reader / VoiceOver

The Touch Bar supports VoiceOver via `NSAccessibility`:
- Each menu item should have an `accessibilityLabel` describing the action
- The currently focused item should be announced
- Navigation: left/right arrow keys cycle items when VoiceOver is active
- Activation: VO+Space to select the focused item
- Menu open/close should announce state change

#### Motor Accessibility

- **Slide-to-select timing**: No time pressure. If finger is down, menu stays open indefinitely.
- **Tap-to-select fallback**: For users who can't do slide-to-select, lifting then tapping works.
- **Timeout**: 3-second idle timeout can be extended to 10s via a setting.
- **Item spacing**: Minimum 8pt gap between items prevents accidental adjacent selection.

#### Cognitive Load

- Maximum 6-8 items per menu level (Miller's law: 7±2)
- Icons paired with text labels where space permits
- Consistent item ordering across sessions (menu items don't rearrange)
- Category items visually distinct from action items (e.g., "▸" suffix for categories)

---

### Context-Specific Menu Contents

Different long-press targets should show different menus:

#### Creature Menu (long-press on creature)

| Item | Icon | Action | Stage Gate |
|------|------|--------|-----------|
| Pet | 🐾 | Trigger petting sequence | None |
| Nap | 💤 | Creature lies down to sleep | Drop+ |
| Talk | 🗣️ | Open speech prompt (if Claude connected) | Beast+ |
| Play | 🎲 | Submenu: available mini-games | Critter+ |
| Tricks | 🎪 | Submenu: taught tricks to perform | Has taught tricks |
| Stats | 📊 | Toggle stats overlay | None |
| Mood | 😊 | Show current emotional state details | Critter+ |

Items are stage-gated: unavailable items simply don't appear (no greyed-out items cluttering the menu at early stages). A Spore creature's menu has only 2-3 items. An Apex creature's menu has 7+.

#### World Menu (long-press on empty space)

| Item | Icon | Action |
|------|------|--------|
| Create | 🪄 | Place a new object (if Claude connected) |
| Weather | 🌤️ | Show current weather + upcoming changes |
| Explore | 🧭 | Pan camera to nearest landmark |
| Journal | 📖 | Show recent journal entries overlay |
| Settings | ⚙️ | System settings submenu |

#### Object Menu (long-press on object)

Object long-press is currently "pick up & move." The context menu could be:
- **Short long-press (500-800ms) + release**: Pick up (current behavior)
- **Extended long-press (800ms+)**: Object menu with: Examine, Move, Remove, Rename

However, this adds complexity to an already-overloaded gesture. **Recommendation**: Keep object long-press as pick-up only. If an object menu is needed later, trigger it via double-tap on object instead.

---

### Animation Specifications

#### Menu Open (Creature-Presented)

```
T+0ms:     Long-press recognized (500ms held). Creature enters "alert" pose.
T+0-300ms: Loading ring indicator fills (thin Gilt arc around creature).
T+300ms:   Ring complete (800ms total hold). Creature sits up.
T+300-500ms: Options expand outward from creature:
             - Each option starts at creature center (scale 0, alpha 0)
             - Stagger: 30ms between each option's start
             - Each option moves to final position (ease-out), scales to 1.0, alpha to 1.0
             - World dims to 60% brightness (overlay node fades in)
T+500ms:   Menu fully open. Awaiting input.
```

SKAction sequence per option:
```swift
let expand = SKAction.group([
    .moveTo(x: targetX, duration: 0.15),     // ease-out
    .scaleTo(1.0, duration: 0.15),
    .fadeAlpha(to: 1.0, duration: 0.15)
])
expand.timingMode = .easeOut
```

Total additional nodes during menu: ~18 (6-8 items x 2 nodes each + overlay + loading ring)

#### Menu Close

```
T+0ms:     Selection made (or cancel).
T+0-150ms: Selected option pulses Gilt (scale 1.0→1.15→1.0).
T+0-200ms: All options contract back to creature center (reverse of open).
             - Scale to 0, alpha to 0, move to creature center
             - World brightens back to 100%
T+200ms:   Menu gone. Creature resumes prior behavior.
             - If an action was selected, it begins executing.
```

#### Frame Budget Impact

| Phase | Additional Cost | Notes |
|-------|----------------|-------|
| Idle (no menu) | 0ms | No menu nodes exist |
| Loading ring | <0.1ms | Single arc shape node |
| Menu open (static) | <0.5ms | 18 nodes, no animation |
| Menu open (hover reactions) | <0.8ms | Creature pose changes + option highlight |
| Menu transition | <1.0ms | 18 nodes animating simultaneously |
| **Worst case total** | **<1.0ms** | Well within 11ms headroom |

---

### Implementation Priority

| Priority | What | Pattern | Effort |
|----------|------|---------|--------|
| **P0** | Creature context menu | Creature-Presented (Pattern 6) | 3-4 tasks |
| **P1** | Duration-based trigger disambiguation | Approach A (500ms vs 800ms) | 1 task |
| **P1** | Affordance system (tutorial + idle pulse) | Options 1+2 | 1 task |
| **P2** | World context menu | Horizontal Strip (Pattern 1) | 2-3 tasks |
| **P2** | Submenu support (lateral slide) | For "Play" submenu | 1-2 tasks |
| **P3** | VoiceOver / accessibility | All patterns | 1 task |
| **P3** | Stage-gated menu content | Dynamic item lists | 1 task |

Total estimated effort: 10-13 tasks across P0-P3 priorities.
