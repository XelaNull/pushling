// CatBehaviors.swift — 12 cat-specific behavior choreographies
// Each behavior is a state machine composing body part controllers.
// Behaviors are triggered by the behavior stack (Phase 2 Track 2),
// but the choreography definitions live here.

import SpriteKit

// MARK: - Cat Behavior Definition

/// A single cat behavior choreography.
struct CatBehavior {
    let name: String
    let minimumStage: GrowthStage
    let durationRange: ClosedRange<TimeInterval>
    let cooldownSeconds: TimeInterval
    let weight: CGFloat              // Base weight for random selection
    let priority: Int                // Within autonomous layer (higher = wins)

    /// Execute the behavior on a creature node.
    /// Returns the estimated duration for this performance.
    let perform: (CreatureNode) -> TimeInterval
}

// MARK: - Cat Behaviors Registry

/// All 12 cat behaviors baked into Layer 1.
enum CatBehaviors {

    /// All registered cat behaviors.
    static let all: [CatBehavior] = [
        slowBlink, kneading, headbutt, predatorCrouch, loaf,
        grooming, zoomies, chattering, ifIFitsISits,
        knockingThingsOff, tailChase, tongueBlep
    ]

    /// Look up a behavior by name.
    static func named(_ name: String) -> CatBehavior? {
        all.first { $0.name == name }
    }

    /// Filter behaviors available at a given stage.
    static func available(at stage: GrowthStage) -> [CatBehavior] {
        all.filter { $0.minimumStage <= stage }
    }

    // MARK: - 1. Slow Blink (Trust/Affection)

    static let slowBlink = CatBehavior(
        name: "slow_blink",
        minimumStage: .drop,
        durationRange: 1.0...1.2,
        cooldownSeconds: 120,
        weight: 0.8,
        priority: 3
    ) { creature in
        // Eyes close halfway, hold, open — the cat trust gesture
        creature.eyeLeftController?.setState("slow_blink", duration: 0)
        creature.eyeRightController?.setState("slow_blink", duration: 0)
        creature.resetBlinkTimer()
        return 1.1  // total slow blink duration
    }

    // MARK: - 2. Kneading (Pre-Sleep Comfort)

    static let kneading = CatBehavior(
        name: "kneading",
        minimumStage: .critter,
        durationRange: 4.0...8.0,
        cooldownSeconds: 300,
        weight: 0.5,
        priority: 2
    ) { creature in
        let duration = TimeInterval.random(in: 4.0...8.0)

        // Front paws alternate pushing
        creature.pawFLController?.setState("knead", duration: 0)
        // Offset the right paw by half a cycle
        let delayRight = SKAction.wait(forDuration: 0.3)
        let startRight = SKAction.run {
            creature.pawFRController?.setState("knead", duration: 0)
        }
        creature.run(SKAction.sequence([delayRight, startRight]),
                     withKey: "kneadRight")

        // Eyes half-closed, content
        creature.eyeLeftController?.setState("half", duration: 0.5)
        creature.eyeRightController?.setState("half", duration: 0.5)

        // Gentle purr — tail slow sway
        creature.tailController?.setState("sway", duration: 0.3)

        // Schedule end
        let end = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run {
                creature.pawFLController?.setState("ground", duration: 0.3)
                creature.pawFRController?.setState("ground", duration: 0.3)
                creature.eyeLeftController?.setState("open", duration: 0.3)
                creature.eyeRightController?.setState("open", duration: 0.3)
            }
        ])
        creature.run(end, withKey: "kneadEnd")

        return duration
    }

    // MARK: - 3. Headbutt (Affection Display)

    static let headbutt = CatBehavior(
        name: "headbutt",
        minimumStage: .critter,
        durationRange: 1.2...1.8,
        cooldownSeconds: 180,
        weight: 0.6,
        priority: 3
    ) { creature in
        // Lean body, push head forward, bonk
        creature.eyeLeftController?.setState("happy", duration: 0.2)
        creature.eyeRightController?.setState("happy", duration: 0.2)

        // Forward push + return
        let push = SKAction.moveBy(x: 3.0, y: 0, duration: 0.3)
        push.timingMode = .easeIn
        let bonk = SKAction.moveBy(x: 2.0, y: 0, duration: 0.1)
        let recoil = SKAction.moveBy(x: -5.0, y: 0, duration: 0.4)
        recoil.timingMode = .easeOut
        let recover = SKAction.run {
            creature.eyeLeftController?.setState("open", duration: 0.2)
            creature.eyeRightController?.setState("open", duration: 0.2)
        }

        creature.run(SKAction.sequence([push, bonk, recoil, recover]),
                     withKey: "headbutt")
        return 1.5
    }

    // MARK: - 4. Predator Crouch (Hunting Incoming Commits)

    static let predatorCrouch = CatBehavior(
        name: "predator_crouch",
        minimumStage: .critter,
        durationRange: 1.5...2.5,
        cooldownSeconds: 60,
        weight: 0.7,
        priority: 5  // High — hunting is important
    ) { creature in
        // Low stance, butt wiggle, ears flat, eyes wide
        creature.earLeftController?.setState("perk", duration: 0.1)
        creature.earRightController?.setState("perk", duration: 0.1)
        creature.eyeLeftController?.setState("wide", duration: 0.1)
        creature.eyeRightController?.setState("wide", duration: 0.1)
        creature.tailController?.setState("twitch_tip", duration: 0.1)

        // Body drops lower (compress Y)
        let crouch = SKAction.scaleY(to: 0.85, duration: 0.2)
        crouch.timingMode = .easeOut
        creature.run(crouch, withKey: "crouchDown")

        // Butt wiggle
        let wiggleR = SKAction.moveBy(x: 0.5, y: 0, duration: 0.1)
        let wiggleL = SKAction.moveBy(x: -1.0, y: 0, duration: 0.1)
        let wiggleBack = SKAction.moveBy(x: 0.5, y: 0, duration: 0.1)
        let wiggle = SKAction.sequence([wiggleR, wiggleL, wiggleBack])
        let wiggleDelay = SKAction.wait(forDuration: 0.5)

        let recover = SKAction.run {
            creature.earLeftController?.setState("neutral", duration: 0.2)
            creature.earRightController?.setState("neutral", duration: 0.2)
            creature.eyeLeftController?.setState("open", duration: 0.2)
            creature.eyeRightController?.setState("open", duration: 0.2)
            creature.tailController?.setState("sway", duration: 0.3)
        }
        let standUp = SKAction.scaleY(to: 1.0, duration: 0.2)

        creature.run(SKAction.sequence([
            wiggleDelay,
            SKAction.repeat(wiggle, count: 3),
            recover, standUp
        ]), withKey: "predatorCrouch")

        return 2.0
    }

    // MARK: - 5. Loaf (Maximum Comfort)

    static let loaf = CatBehavior(
        name: "loaf",
        minimumStage: .critter,
        durationRange: 30.0...60.0,
        cooldownSeconds: 600,
        weight: 0.3,
        priority: 1  // Low — easily interrupted
    ) { creature in
        let duration = TimeInterval.random(in: 30.0...60.0)

        // Tuck all paws under body
        creature.pawFLController?.setState("tuck", duration: 0.5)
        creature.pawFRController?.setState("tuck", duration: 0.5)
        creature.pawBLController?.setState("tuck", duration: 0.5)
        creature.pawBRController?.setState("tuck", duration: 0.5)

        // Tail wraps or sways slowly
        creature.tailController?.setState("wrap", duration: 0.5)

        // Eyes content — half-lidded
        creature.eyeLeftController?.setState("half", duration: 0.5)
        creature.eyeRightController?.setState("half", duration: 0.5)

        // Ears relaxed
        creature.earLeftController?.setState("neutral", duration: 0.3)
        creature.earRightController?.setState("neutral", duration: 0.3)

        // Schedule end
        let end = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run {
                creature.pawFLController?.setState("ground", duration: 0.5)
                creature.pawFRController?.setState("ground", duration: 0.5)
                creature.pawBLController?.setState("ground", duration: 0.5)
                creature.pawBRController?.setState("ground", duration: 0.5)
                creature.tailController?.setState("sway", duration: 0.5)
                creature.eyeLeftController?.setState("open", duration: 0.3)
                creature.eyeRightController?.setState("open", duration: 0.3)
            }
        ])
        creature.run(end, withKey: "loafEnd")

        return duration
    }

    // MARK: - 6. Grooming (Post-Meal, Idle)

    static let grooming = CatBehavior(
        name: "grooming",
        minimumStage: .critter,
        durationRange: 3.0...5.0,
        cooldownSeconds: 240,
        weight: 0.5,
        priority: 2
    ) { creature in
        let duration = TimeInterval.random(in: 3.0...5.0)

        // Lift front-left paw to face
        creature.pawFLController?.setState("lift", duration: 0.3)

        // Mouth licking
        let startLick = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run {
                creature.mouthController?.setState("lick", duration: 0)
            }
        ])
        creature.run(startLick, withKey: "groomLick")

        // Head tilts slightly
        let tilt = SKAction.rotate(byAngle: 0.1, duration: 0.3)
        let untilt = SKAction.rotate(byAngle: -0.1, duration: 0.3)
        creature.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            tilt,
            SKAction.wait(forDuration: duration - 1.0),
            untilt
        ]), withKey: "groomTilt")

        // Schedule end
        let end = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run {
                creature.pawFLController?.setState("ground", duration: 0.3)
                creature.mouthController?.setState("closed", duration: 0.2)
            }
        ])
        creature.run(end, withKey: "groomEnd")

        return duration
    }

    // MARK: - 7. Zoomies (Sudden Speed Burst)

    static let zoomies = CatBehavior(
        name: "zoomies",
        minimumStage: .critter,
        durationRange: 2.0...4.0,
        cooldownSeconds: 600,
        weight: 0.2,  // Rare but delightful
        priority: 6   // High — zoomies override almost everything
    ) { creature in
        let duration = TimeInterval.random(in: 2.0...4.0)

        // Tail poofs up
        creature.tailController?.setState("poof", duration: 0.1)

        // Ears go wild
        creature.earLeftController?.setState("wild", duration: 0)
        creature.earRightController?.setState("wild", duration: 0)

        // Eyes wide
        creature.eyeLeftController?.setState("wide", duration: 0.1)
        creature.eyeRightController?.setState("wide", duration: 0.1)

        // All paws in run mode
        creature.pawFLController?.setState("run", duration: 0)
        creature.pawFRController?.setState("run", duration: 0)
        creature.pawBLController?.setState("run", duration: 0)
        creature.pawBRController?.setState("run", duration: 0)

        // Sprint across the bar would be handled by the behavior stack
        // (movement is not this choreography's job — just body states)

        // Schedule wind-down
        let windDown = SKAction.sequence([
            SKAction.wait(forDuration: duration - 0.5),
            SKAction.run {
                creature.tailController?.setState("sway_fast",
                                                   duration: 0.2)
                creature.earLeftController?.setState("perk", duration: 0.1)
                creature.earRightController?.setState("perk", duration: 0.1)
                creature.eyeLeftController?.setState("open", duration: 0.2)
                creature.eyeRightController?.setState("open", duration: 0.2)
                creature.pawFLController?.setState("ground", duration: 0.2)
                creature.pawFRController?.setState("ground", duration: 0.2)
                creature.pawBLController?.setState("ground", duration: 0.2)
                creature.pawBRController?.setState("ground", duration: 0.2)
            },
            SKAction.wait(forDuration: 0.5),
            SKAction.run {
                creature.tailController?.setState("sway", duration: 0.3)
                creature.earLeftController?.setState("neutral",
                                                      duration: 0.2)
                creature.earRightController?.setState("neutral",
                                                       duration: 0.2)
            }
        ])
        creature.run(windDown, withKey: "zoomiesEnd")

        return duration
    }

    // MARK: - 8. Chattering (At Flying Things)

    static let chattering = CatBehavior(
        name: "chattering",
        minimumStage: .critter,
        durationRange: 1.5...2.5,
        cooldownSeconds: 180,
        weight: 0.4,
        priority: 4
    ) { creature in
        // Jaw vibrates rapidly, eyes wide, ears perked, body tense
        creature.mouthController?.setState("chatter", duration: 0)
        creature.eyeLeftController?.setState("wide", duration: 0.1)
        creature.eyeRightController?.setState("wide", duration: 0.1)
        creature.earLeftController?.setState("perk", duration: 0.1)
        creature.earRightController?.setState("perk", duration: 0.1)
        creature.tailController?.setState("twitch_tip", duration: 0.1)

        // Auto-end after 2s
        let end = SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run {
                creature.mouthController?.setState("closed", duration: 0.2)
                creature.eyeLeftController?.setState("open", duration: 0.2)
                creature.eyeRightController?.setState("open", duration: 0.2)
                creature.earLeftController?.setState("neutral",
                                                      duration: 0.2)
                creature.earRightController?.setState("neutral",
                                                       duration: 0.2)
                creature.tailController?.setState("sway", duration: 0.3)
            }
        ])
        creature.run(end, withKey: "chatterEnd")

        return 2.0
    }

    // MARK: - 9. If I Fits I Sits

    static let ifIFitsISits = CatBehavior(
        name: "if_i_fits_i_sits",
        minimumStage: .critter,
        durationRange: 10.0...20.0,
        cooldownSeconds: 600,
        weight: 0.2,
        priority: 2
    ) { creature in
        let duration = TimeInterval.random(in: 10.0...20.0)

        // Squeeze into a compact form
        let squeeze = SKAction.scaleX(to: 0.8, duration: 0.5)
        squeeze.timingMode = .easeInEaseOut
        creature.run(squeeze, withKey: "fitsSqueezeX")

        // Happy eyes
        creature.eyeLeftController?.setState("happy", duration: 0.3)
        creature.eyeRightController?.setState("happy", duration: 0.3)

        // Slow tail sway
        creature.tailController?.setState("sway", duration: 0.3)

        // Tuck paws
        creature.pawFLController?.setState("tuck", duration: 0.5)
        creature.pawFRController?.setState("tuck", duration: 0.5)
        creature.pawBLController?.setState("tuck", duration: 0.5)
        creature.pawBRController?.setState("tuck", duration: 0.5)

        // Schedule end
        let end = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run {
                creature.run(SKAction.scaleX(to: 1.0, duration: 0.3),
                             withKey: "fitsUnsqueezeX")
                creature.eyeLeftController?.setState("open", duration: 0.2)
                creature.eyeRightController?.setState("open", duration: 0.2)
                creature.pawFLController?.setState("ground", duration: 0.3)
                creature.pawFRController?.setState("ground", duration: 0.3)
                creature.pawBLController?.setState("ground", duration: 0.3)
                creature.pawBRController?.setState("ground", duration: 0.3)
            }
        ])
        creature.run(end, withKey: "fitsEnd")

        return duration
    }

    // MARK: - 10. Knocking Things Off (Mischief)

    static let knockingThingsOff = CatBehavior(
        name: "knocking_things_off",
        minimumStage: .beast,
        durationRange: 2.5...3.5,
        cooldownSeconds: 420,
        weight: 0.3,
        priority: 3
    ) { creature in
        // Paw swipe at object, look at camera, pause, push
        creature.pawFLController?.setState("lift", duration: 0.2)

        // Look at camera (eyes shift toward viewer)
        let lookAtCamera = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run {
                creature.eyeLeftController?.setState("squint",
                                                      duration: 0.2)
                creature.eyeRightController?.setState("squint",
                                                       duration: 0.2)
            }
        ])
        creature.run(lookAtCamera, withKey: "knockLook")

        // Pause for dramatic effect, then swipe
        let swipeAction = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run {
                creature.pawFLController?.setState("swipe", duration: 0)
                creature.eyeLeftController?.setState("happy", duration: 0.1)
                creature.eyeRightController?.setState("happy",
                                                       duration: 0.1)
            },
            SKAction.wait(forDuration: 1.0),
            SKAction.run {
                creature.pawFLController?.setState("ground", duration: 0.3)
                creature.eyeLeftController?.setState("open", duration: 0.2)
                creature.eyeRightController?.setState("open", duration: 0.2)
            }
        ])
        creature.run(swipeAction, withKey: "knockSwipe")

        return 3.0
    }

    // MARK: - 11. Tail Chase (Spinning Fun)

    static let tailChase = CatBehavior(
        name: "tail_chase",
        minimumStage: .critter,
        durationRange: 4.0...6.0,
        cooldownSeconds: 480,
        weight: 0.2,
        priority: 3
    ) { creature in
        let duration = TimeInterval.random(in: 4.0...6.0)

        // Body spins
        creature.tailController?.setState("chase", duration: 0)

        // Eyes focused then dizzy
        creature.eyeLeftController?.setState("wide", duration: 0.1)
        creature.eyeRightController?.setState("wide", duration: 0.1)

        // Spin the whole creature
        let spinDuration = duration - 1.0
        let spin = SKAction.rotate(byAngle: .pi * 6, duration: spinDuration)
        spin.timingMode = .easeInEaseOut

        let getDizzy = SKAction.run {
            // Dizzy eyes — slightly squinted, offset
            creature.eyeLeftController?.setState("squint", duration: 0.2)
            creature.eyeRightController?.setState("half", duration: 0.2)
        }

        let recover = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run {
                creature.eyeLeftController?.setState("open", duration: 0.3)
                creature.eyeRightController?.setState("open", duration: 0.3)
                creature.tailController?.setState("sway", duration: 0.3)
            }
        ])

        creature.run(SKAction.sequence([spin, getDizzy, recover]),
                     withKey: "tailChase")

        return duration
    }

    // MARK: - 12. Tongue Blep (Surprise #42)

    static let tongueBlep = CatBehavior(
        name: "tongue_blep",
        minimumStage: .drop,
        durationRange: 15.0...30.0,
        cooldownSeconds: 600,
        weight: 0.15,  // Rare
        priority: 1    // Low — creature acts normal except tongue is out
    ) { creature in
        let duration = TimeInterval.random(in: 15.0...30.0)

        // Tongue stays out, creature acts completely normal otherwise
        creature.mouthController?.setState("blep", duration: 0)

        // Schedule auto-retract
        let end = SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run {
                creature.mouthController?.setState("closed", duration: 0.2)
            }
        ])
        creature.run(end, withKey: "blepEnd")

        return duration
    }
}
