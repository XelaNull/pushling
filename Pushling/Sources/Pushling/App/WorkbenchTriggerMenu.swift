// WorkbenchTriggerMenu.swift — WO-7 incr 2-3, trigger grid.
//
// An in-workbench control surface to fire behaviors/poses on demand, so
// the creature can be driven without the Touch Bar. Mirrors the existing
// debug-menu pattern (AppDelegate+Debug.swift's `buildDebugSubmenu()` +
// `addItem(to:_:_:)`-style construction) rather than inventing a new one.
//
// Two sections, two different (both anti-flicker) mechanisms:
//   Section A — perform actions: routed through
//     `commandRouter.route(IPCRequest(cmd: "perform", action: …))`, the
//     EXACT same in-process entry point (`ActionHandlers.handlePerform` ->
//     taught tricks -> CatBehaviors -> PerformActionMapping) a real socket
//     `perform` command takes. No new IPC path — the workbench's
//     CommandRouter has no SocketServer wrapping it, so there's no
//     SESSION_REQUIRED gate to satisfy (that check lives entirely in
//     SocketServer.processMessage, not CommandRouter itself).
//   Section B — core bodyStates with no perform-action route: injected
//     via `AIDirectedLayer.debugSetBodyState(_:duration:)`
//     (DebugExtensions.swift) — a PERSISTENT AI-layer command, not a raw
//     `bodyPoseController.setState()` poke. This is the anti-PARADE-
//     HARNESS mechanism: `PushlingScene.applyBehaviorOutput` unconditionally
//     re-drives `bodyState` every frame from the resolved 4-layer stack,
//     so a poke that bypasses the layers renders for under a frame (the
//     exact bug WO-19 sub-part 2's REVISE removed). `"loaf"` is routed
//     here specifically because the `perform` action name "loaf" is
//     shadowed by `CatBehaviors.loaf` (CatBehaviors.swift:186..., checked
//     before PerformActionMapping in ActionHandlers.handlePerform) — this
//     is the only way to actually exercise bodyState "loaf" in the
//     workbench today.
//
// Threading: every trigger dispatches onto `DispatchQueue.global().async`,
// mirroring the real socket server's threading model (IPC handlers run off
// the main thread there too) — this also matters because SOME CommandRouter
// handlers (`screenshot`/`debug_nodes`) internally hop to main and block-
// wait; calling those synchronously from a main-thread button action would
// deadlock. `perform` itself doesn't do that hop, but dispatching
// uniformly avoids ever having to reason about which commands are "safe"
// to call from main.
//
// Architecture-agnostic: every trigger ends at `bodyState`/behavior-stack
// channels, never touches CreatureNode's rendering internals directly —
// nothing here assumes today's vector rig over a later sprite-frame body.

import AppKit

extension WorkbenchWindowController {

    // MARK: - Item Lists

    /// `PerformActionMapping`'s 24 actions minus `"loaf"` (shadowed by
    /// CatBehaviors — see the file header) plus the 12 `CatBehaviors`
    /// names (also resolved via the same `perform` action-name path).
    private static let performActions: [String] = [
        // PerformActionMapping rows (CommandRouter.validActions["perform"], minus "loaf")
        "backflip", "bow", "celebrate", "conduct", "curl", "dance", "dig",
        "examine", "flex", "glitch", "groom", "knead", "meditate", "nap",
        "peek", "play_dead", "shiver", "sphinx", "spin", "sprawl",
        "stretch", "transcend", "wave",
        // CatBehaviors.all names (also resolved through the same `perform`
        // action-name path — ActionHandlers.handlePerform checks these
        // BEFORE PerformActionMapping)
        "chattering", "grooming", "headbutt", "if_i_fits_i_sits",
        "kneading", "knocking_things_off", "loaf", "predator_crouch",
        "slow_blink", "tail_chase", "tongue_blep", "zoomies",
    ]

    /// Core bodyStates with no clean `perform`-action route (reflex/
    /// physics-only states, or ones worth isolating from the extra
    /// channels their perform action also sets) + `"loaf"` (see header).
    private static let coreBodyStates: [String] = [
        "alert", "bounce", "crouch", "flinch", "flip", "float", "jump",
        "land", "loaf", "pounce", "roll_side", "shake", "shiver", "spin",
    ]

    /// Hold duration for Section B's direct bodyState injection — matches
    /// PerformActionMapping's typical 2-8s range, long enough to judge in
    /// the workbench without needing to re-trigger constantly.
    private static let bodyStateHoldDuration: TimeInterval = 8.0

    // MARK: - Menu Construction

    /// Builds the trigger menu fresh each time it's shown (cheap — a
    /// couple dozen NSMenuItems) rather than caching, so item lists can
    /// be edited without touching any caching/invalidation logic.
    func buildTriggerMenu() -> NSMenu {
        let menu = NSMenu(title: "Trigger")

        addSectionHeader(to: menu, "Perform Actions (perform command path)")
        for action in Self.performActions {
            addTriggerItem(to: menu, title: action, representedObject: action,
                          action: #selector(triggerPerformAction(_:)))
        }

        menu.addItem(.separator())
        addSectionHeader(to: menu, "Core BodyStates (direct AI-layer inject)")
        for state in Self.coreBodyStates {
            addTriggerItem(to: menu, title: state, representedObject: state,
                          action: #selector(triggerBodyState(_:)))
        }

        return menu
    }

    private func addSectionHeader(to menu: NSMenu, _ title: String) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
    }

    private func addTriggerItem(to menu: NSMenu, title: String,
                                 representedObject: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = representedObject
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc func showTriggerMenu(_ sender: NSButton) {
        let menu = buildTriggerMenu()
        menu.popUp(positioning: nil,
                  at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    /// Section A — routes through the real `perform` command path,
    /// in-process, off the main thread.
    @objc func triggerPerformAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String else { return }
        lastTriggeredLabel = action
        statusLabel.stringValue = "Triggered (perform): \(action)"

        let request = IPCRequest(
            id: UUID().uuidString, cmd: "perform",
            action: action, params: [:], sessionId: nil
        )
        let router = commandRouter
        DispatchQueue.global().async {
            let result = router.route(request)
            if !result.ok {
                NSLog("[Pushling/Workbench] perform '%@' failed: %@",
                      action, result.error ?? "unknown error")
            }
        }
    }

    /// Section B — direct AI-layer bodyState injection (the anti-PARADE-
    /// HARNESS mechanism, DebugExtensions.swift's `debugSetBodyState`).
    @objc func triggerBodyState(_ sender: NSMenuItem) {
        guard let bodyState = sender.representedObject as? String else { return }
        lastTriggeredLabel = bodyState
        statusLabel.stringValue = "Triggered (bodyState): \(bodyState)"

        let aiDirected = gameCoordinator.scene.behaviorStack?.aiDirected
        DispatchQueue.global().async {
            guard let aiLayer = aiDirected else {
                NSLog("[Pushling/Workbench] bodyState '%@' failed: no AI layer available",
                      bodyState)
                return
            }
            aiLayer.debugSetBodyState(bodyState, duration: Self.bodyStateHoldDuration)
        }
    }
}
