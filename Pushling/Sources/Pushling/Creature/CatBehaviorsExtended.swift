// CatBehaviorsExtended.swift — Cat behaviors 7-12
// Extension of CatBehaviors with zoomies, chattering, if-i-fits-i-sits,
// knocking things off, tail chase, and tongue blep.

import SpriteKit

extension CatBehaviors {

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
