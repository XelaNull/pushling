// VisualSurprises.swift — Surprises #1-12: spontaneous visual gags
// These are the most frequent surprises — pure visual delight.
// Each has a complete keyframe animation using body part controllers.

import Foundation
import CoreGraphics

enum VisualSurprises {

    static let all: [SurpriseDefinition] = [
        sneeze, chase, handstand, prank, bellyFlop,
        shadowPlay, puddleDiscovery, dustBunny, invisibleBarrier,
        clone, tinyTrumpet, gravityFlip
    ]

    // MARK: - #1 Sneeze

    static let sneeze = SurpriseDefinition(
        id: 1, name: "Sneeze", category: .visual,
        stageMin: .drop, weight: 1.2,
        cooldown: 300, duration: 2.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.6) { $0.eyes = "squint"; $0.ears = "flat"; $0.mouth = "closed"; $0.tail = "still"; $0.body = "crouch" },
                kf(0.6, 0.3) { $0.eyes = "closed"; $0.ears = "back"; $0.mouth = "open_wide"; $0.tail = "poof"; $0.body = "jolt_forward"; $0.easing = .snap },
                kf(0.9, 0.5) { $0.eyes = "half"; $0.ears = "neutral"; $0.mouth = "closed"; $0.tail = "sway"; $0.body = "stand" },
                KF.normal(at: 1.5)
            ], journalSummary: "Sneezed — a tiny but mighty achoo")
        }
    )

    // MARK: - #2 Chase

    static let chase = SurpriseDefinition(
        id: 2, name: "Chase", category: .visual,
        stageMin: .critter, weight: 0.8,
        cooldown: 600, duration: 10.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.tail = "still"; $0.body = "alert" },
                kf(0.5, 1.0) { $0.eyes = "narrow"; $0.ears = "flat"; $0.tail = "low"; $0.body = "crouch"; $0.paws = ["fl": "crouch", "fr": "crouch", "bl": "crouch", "br": "crouch"] },
                kf(1.5, 1.5) { $0.eyes = "narrow"; $0.ears = "flat"; $0.tail = "wiggle"; $0.body = "wiggle" },
                kf(3.0, 2.0) { $0.eyes = "wide"; $0.ears = "flat"; $0.body = "run"; $0.speed = 80; $0.facing = .right },
                kf(5.0, 2.0) { $0.body = "run"; $0.speed = 80; $0.facing = .left },
                kf(7.0, 1.0) { $0.eyes = "half"; $0.ears = "droop"; $0.body = "stand"; $0.speed = 0 },
                kf(8.0, 1.5) { $0.eyes = "closed"; $0.ears = "neutral"; $0.body = "groom"; $0.tail = "sway" },
                KF.normal(at: 9.5)
            ], journalSummary: "Chased a mouse across the bar. Missed. Groomed.")
        }
    )

    // MARK: - #3 Handstand

    static let handstand = SurpriseDefinition(
        id: 3, name: "Handstand", category: .visual,
        stageMin: .beast, weight: 0.6,
        cooldown: 600, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "focused"; $0.ears = "perk"; $0.body = "handstand_prep"; $0.paws = ["fl": "press", "fr": "press", "bl": "lift", "br": "lift"] },
                kf(1.0, 2.0) { $0.eyes = "wide"; $0.ears = "flat"; $0.tail = "balance"; $0.body = "handstand" },
                kf(3.0, 0.5) { $0.eyes = "closed"; $0.ears = "back"; $0.body = "tumble"; $0.tail = "poof"; $0.easing = .snap },
                kf(3.5, 1.0) { $0.eyes = "proud"; $0.ears = "perk"; $0.tail = "high"; $0.body = "stand"; $0.speech = "nailed it"; $0.speechStyle = .say },
                KF.normal(at: 4.5)
            ], journalSummary: "Attempted a handstand. Tumbled. Called it a success.")
        }
    )

    // MARK: - #4 Prank

    static let prank = SurpriseDefinition(
        id: 4, name: "Prank", category: .visual,
        stageMin: .critter, weight: 0.7,
        cooldown: 600, duration: 6.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "narrow"; $0.ears = "flat"; $0.body = "sneak"; $0.speed = 5 },
                kf(1.5, 2.0) { $0.eyes = "peek"; $0.ears = "perk"; $0.body = "hide_peek" },
                kf(3.5, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.mouth = "open_wide"; $0.body = "jump"; $0.speech = "boo!"; $0.speechStyle = .exclaim },
                kf(4.5, 1.0) { $0.eyes = "smug"; $0.ears = "neutral"; $0.mouth = "smirk" },
                KF.normal(at: 5.5)
            ], journalSummary: "Hid behind something and jumped out. Boo!")
        }
    )

    // MARK: - #5 Belly Flop

    static let bellyFlop = SurpriseDefinition(
        id: 5, name: "Belly Flop", category: .visual,
        stageMin: .drop, weight: 0.8,
        cooldown: 300, duration: 3.0,
        isEligible: { ctx in ctx.stage == .drop },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "focused"; $0.body = "wobble" },
                kf(0.5, 0.5) { $0.eyes = "closed"; $0.body = "splat"; $0.easing = .snap },
                kf(1.0, 0.5) { $0.eyes = "wide"; $0.body = "bounce" },
                kf(1.5, 1.0) { $0.eyes = "half"; $0.body = "splat"; $0.speech = "..."; $0.speechStyle = .say },
                KF.normal(at: 2.5)
            ], journalSummary: "Belly-flopped. Still learning this body.")
        }
    )

    // MARK: - #6 Shadow Play

    static let shadowPlay = SurpriseDefinition(
        id: 6, name: "Shadow Play", category: .visual,
        stageMin: .beast, weight: 0.5,
        cooldown: 900, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.body = "stand"; $0.tail = "sway" },
                kf(2.0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.tail = "still" },
                kf(3.0, 0.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.facing = .left; $0.easing = .snap },
                kf(3.5, 0.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.facing = .right; $0.easing = .snap },
                kf(4.0, 0.5) { $0.eyes = "wide"; $0.ears = "back"; $0.facing = .left; $0.easing = .snap },
                kf(4.5, 2.0) { $0.eyes = "wide"; $0.ears = "flat"; $0.body = "back_away"; $0.speed = 5; $0.facing = .right },
                kf(6.5, 1.0) { $0.eyes = "confused"; $0.ears = "rotate_toward"; $0.body = "stand"; $0.speed = 0 },
                KF.normal(at: 7.5)
            ], journalSummary: "Shadow went rogue. Creature was alarmed. It came back.")
        }
    )

    // MARK: - #7 Puddle Discovery

    static let puddleDiscovery = SurpriseDefinition(
        id: 7, name: "Puddle Discovery", category: .visual,
        stageMin: .critter, weight: 0.7,
        cooldown: 600, duration: 6.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "crouch"; $0.speed = 0 },
                kf(1.0, 1.0) { $0.eyes = "curious"; $0.ears = "tilt_left"; $0.body = "head_tilt_left" },
                kf(2.0, 1.0) { $0.eyes = "wide"; $0.paws = ["fl": "tap", "fr": "ground", "bl": "ground", "br": "ground"] },
                kf(3.0, 1.0) { $0.eyes = "curious"; $0.ears = "tilt_right"; $0.body = "head_tilt_right" },
                kf(4.0, 1.5) { $0.eyes = "closed"; $0.ears = "forward"; $0.body = "sniff"; $0.mouth = "sniff" },
                KF.normal(at: 5.5)
            ], journalSummary: "Found a puddle. Met someone interesting in the reflection.")
        }
    )

    // MARK: - #8 Dust Bunny

    static let dustBunny = SurpriseDefinition(
        id: 8, name: "Dust Bunny", category: .visual,
        stageMin: .critter, weight: 0.4,
        cooldown: 1800, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert" },
                kf(1.0, 1.5) { $0.eyes = "curious"; $0.ears = "forward"; $0.body = "sniff_down" },
                kf(2.5, 2.0) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "stand"; $0.speed = 8; $0.facing = .right },
                kf(4.5, 1.5) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "look_back"; $0.speed = 0 },
                kf(6.0, 1.5) { $0.eyes = "soft"; $0.ears = "droop"; $0.body = "stand" },
                KF.normal(at: 7.5)
            ], journalSummary: "Made friends with a dust bunny. It didn't last.")
        }
    )

    // MARK: - #9 Invisible Barrier

    static let invisibleBarrier = SurpriseDefinition(
        id: 9, name: "Invisible Barrier", category: .visual,
        stageMin: .beast, weight: 0.6,
        cooldown: 600, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.3) { $0.body = "stand"; $0.speed = 15; $0.facing = .right },
                kf(0.3, 1.0) { $0.eyes = "squished"; $0.ears = "flat"; $0.body = "flat_press"; $0.paws = ["fl": "press", "fr": "press", "bl": "ground", "br": "ground"]; $0.speed = 0; $0.easing = .snap },
                kf(1.3, 1.0) { $0.eyes = "confused"; $0.ears = "rotate_toward"; $0.body = "back_away"; $0.speed = 5 },
                kf(2.3, 0.5) { $0.eyes = "determined"; $0.body = "walk"; $0.speed = 10 },
                kf(2.8, 1.0) { $0.paws = ["fl": "tap", "fr": "tap", "bl": "ground", "br": "ground"]; $0.speed = 0 },
                kf(3.8, 0.7) { $0.eyes = "suspicious"; $0.body = "walk"; $0.speed = 8 },
                KF.normal(at: 4.5)
            ], journalSummary: "Hit an invisible wall. Suspects mime conspiracy.")
        }
    )

    // MARK: - #10 Clone

    static let clone = SurpriseDefinition(
        id: 10, name: "Clone", category: .visual,
        stageMin: .sage, weight: 0.4,
        cooldown: 1200, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.body = "flicker" },
                kf(0.5, 1.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "head_tilt_left" },
                kf(2.0, 0.5) { $0.body = "stand" },
                kf(2.5, 1.0) { $0.eyes = "confused"; $0.speech = "...huh."; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "Briefly had a clone. They stared at each other. Weird.")
        }
    )

    // MARK: - #11 Tiny Trumpet

    static let tinyTrumpet = SurpriseDefinition(
        id: 11, name: "Tiny Trumpet", category: .visual,
        stageMin: .beast, weight: 0.5,
        cooldown: 900, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.body = "reach_behind" },
                kf(0.5, 0.5) { $0.eyes = "focused"; $0.ears = "perk"; $0.paws = ["fl": "hold", "fr": "hold", "bl": "ground", "br": "ground"] },
                kf(1.0, 1.5) { $0.eyes = "closed"; $0.ears = "neutral"; $0.mouth = "trumpet"; $0.body = "playing" },
                kf(2.5, 1.0) { $0.eyes = "proud"; $0.ears = "perk"; $0.body = "stand"; $0.tail = "high" },
                KF.normal(at: 3.5)
            ], journalSummary: "Produced a tiny trumpet from nowhere. Played a fanfare. Proud.")
        }
    )

    // MARK: - #12 Gravity Flip

    static let gravityFlip = SurpriseDefinition(
        id: 12, name: "Gravity Flip", category: .visual,
        stageMin: .sage, weight: 0.3,
        cooldown: 1800, duration: 12.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "float_up" },
                kf(1.0, 8.0) { $0.body = "walk_inverted"; $0.tail = "sway"; $0.speed = 15 },
                kf(9.0, 1.0) { $0.body = "fall"; $0.easing = .snap },
                kf(10.0, 1.5) { $0.eyes = "neutral"; $0.body = "stand"; $0.tail = "sway" },
                KF.normal(at: 11.5)
            ], journalSummary: "Walked on the ceiling for 10 seconds. Did not acknowledge it.")
        }
    )
}
