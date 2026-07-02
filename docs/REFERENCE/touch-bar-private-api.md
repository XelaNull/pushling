---
type: Reference
title: NSTouchBar Private API and Native Rendering Reference
description: The DFR private-API surface and the SKView-in-NSCustomTouchBarItem embedding technique the Pushling daemon uses to own the Touch Bar at 60fps, including the corrected touch-delivery limitation.
status: Live
tags: [touch-bar, private-api, dfr, spritekit, touch]
timestamp: 2026-07-02T00:00:00Z
---

`NSCustomTouchBarItem` accepts any `NSView` subclass — this is the single
fact that makes a full SpriteKit game engine possible inside the Touch Bar,
proven by 5+ shipped community games before Pushling. This concept documents
the exact private-API surface Pushling uses to take over the Touch Bar and
embed its SpriteKit scene, verified line-for-line against
`Pushling/Sources/Pushling/TouchBar/`.

# The Private API Surface

Pushling loads `DFRFoundation.framework` dynamically (`dlopen`/`dlsym`) —
never linked at compile time — so the app degrades gracefully on hardware
without a Touch Bar rather than crashing (`DFRFoundationLoader`,
`TouchBar/DFRPrivateAPI.swift`):

| Symbol | Resolution mechanism | Purpose |
|---|---|---|
| `DFRSystemModalShowsCloseBoxWhenFrontMost(Bool)` | `dlsym` — true C function in `DFRFoundation.framework` | Hides the system close-box while our Touch Bar is frontmost |
| `DFRElementSetControlStripPresenceForIdentifier(NSString, Bool)` | `dlsym` — true C function | Registers/unregisters an item's presence in the Control Strip region |
| `NSTouchBar.presentSystemModalTouchBar(_:placement:systemTrayItemIdentifier:)` | Objective-C runtime: `NSSelectorFromString` + `class_getClassMethod` + `unsafeBitCast` to a C-convention function pointer | Takes over the system Touch Bar with our own `NSTouchBar` |
| `NSTouchBar.dismissSystemModalTouchBar(_:)` | Same runtime-introspection technique | Releases the system-modal takeover |
| `NSTouchBar.minimizeSystemModalTouchBar(_:)` | Same technique, failure is silent (optional capability) | Collapses to a Control Strip item |
| `NSTouchBarItem.addSystemTrayItem(_:)` | Same technique | Registers an item with the system tray — must be called *before* setting Control Strip presence, or the presence flag has nothing to display |
| `NSTouchBarItem.removeSystemTrayItem(_:)` | Same technique | Unregisters a system tray item |

**Correction to prior research:** the two `DFR*` functions are true C
symbols resolved via `dlsym` against the private framework binary — the
original research doc's flat Objective-C-style declarations (lifted from
Pock's source) obscured this distinction. The five `NSTouchBar`/
`NSTouchBarItem` methods, by contrast, are genuine Objective-C class
methods with no public header — Pushling resolves them at runtime via
`NSSelectorFromString` + `class_getClassMethod` + `method_getImplementation`,
cast to a `@convention(c)` function pointer, rather than `dlsym`. Both
techniques exist in the same file for a reason: C functions and Objective-C
methods require different resolution strategies, and `DFRPrivateAPI.swift`
demonstrates both.

# SKView Embedding (The "Nuclear Option," Realized)

`TouchBarController` never dismisses the system-modal Touch Bar outright.
Instead it owns two `NSTouchBar` instances and toggles between them:

- **Scene bar** — a full `SKView` (subclassed as `TouchBarView`) at
  1085x30pt, `preferredFramesPerSecond = 60`, presenting `PushlingScene`
- **Controls bar** — a lightweight bar of plain `NSButton`s for brightness,
  volume, and keyboard backlight, used when the developer needs the
  Mac's actual system controls

`toggleVisibility()` swaps between them by dismissing one system-modal
presentation and presenting the other — the app always owns *a* Touch Bar,
it just changes which content is showing. `presentAsSystemModal` is called
with `placement: 1` (replace the system function-bar region) each time.

# Touch Delivery: The Corrected Caveat

Prior research assumed `touchesMoved` on a custom view gives sub-pixel,
~60Hz positional touch, citing TouchBreakout as proof. **Verified against
`TouchBarView.swift`, this does not hold for Pushling's `SKView`:**

- `NSTouch.normalizedPosition` — the API `SKView.touchesBegan` internally
  reads — is trackpad-only and **crashes** when accessed from a genuine
  Touch Bar touch event. `TouchBarView` overrides all four touch methods
  (`touchesBegan/Moved/Ended/Cancelled`) as **no-ops specifically to
  prevent this crash**, sacrificing `SKView`'s built-in touch handling
  entirely.
- **Gesture recognizers added directly to the `SKView` also do not fire**
  on Touch Bar hardware. Only gesture recognizers attached to a genuine
  plain `NSView` subview receive events.
- In practice, this means **only the P button and menu-strip buttons**
  (each their own `NSView` subclass with an `NSClickGestureRecognizer`)
  currently receive touch input. **Tapping the creature or the scene area
  directly does not work** — this is an explicit `TODO` in the source
  (`TouchBarView.swift:56-59`), not a rendering choice.
- The scene's own tap-to-pet/tap-to-play interaction (`handleClick`,
  `handlePan`) is implemented as if wired to a container overlay
  (`wireGestureRecognizers(on container: NSView)`, a `touchOverlay`
  property), but **neither is ever called or assigned anywhere in the
  codebase** — this is unwired dead code, not a working fallback. Any
  existing tap response the creature does have arrives through a different
  path than this mechanism; this file does not claim to resolve which.

This is flagged for the Orchestrator/`DECISIONS.md`: the unwired
`wireGestureRecognizers`/`touchOverlay` pair is a "defined but unwired"
finding, independent of the survey's original driftSignal about the
touch-delivery claim itself.

# Citations

[1] `Pushling/Sources/Pushling/TouchBar/DFRPrivateAPI.swift`
[2] `Pushling/Sources/Pushling/TouchBar/TouchBarController.swift`
[3] `Pushling/Sources/Pushling/TouchBar/TouchBarView.swift`
[4] `docs/archive/TOUCHBAR-TECHNIQUES.md` — §3.3 (Native NSTouchBar API), §6.2-6.3 (Input Latency, Positional Touch)
