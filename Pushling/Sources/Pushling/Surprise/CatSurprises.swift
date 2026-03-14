// CatSurprises.swift — Surprises #27-42: cat-specific behaviors
// The heart of the surprise system — these are what make it a cat.

import Foundation
import CoreGraphics

enum CatSurprises {

    static let all: [SurpriseDefinition] = [
        zoomies, knockingThingsOff, ifIFitsISits, tailChasing,
        chattering, kneadingSession, theLoaf, headInBox,
        giftDelivery, buttWiggle, whiskerTwitch, slowRollBellyTrap,
        perching, breadMaking, midnightCrazies, tongueBlep
    ]

    // MARK: - #27 Zoomies

    static let zoomies = SurpriseDefinition(
        id: 27, name: "Zoomies", category: .cat,
        stageMin: .critter, weight: 1.0,
        cooldown: 600, duration: 3.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "flat"; $0.body = "run"; $0.tail = "poof"; $0.speed = 100; $0.facing = .right; $0.easing = .snap },
                kf(1.0, 1.0) { $0.eyes = "wide"; $0.ears = "flat"; $0.body = "run"; $0.tail = "poof"; $0.speed = 100; $0.facing = .left; $0.easing = .snap },
                kf(2.0, 0.8) { $0.eyes = "closed"; $0.ears = "neutral"; $0.body = "groom"; $0.tail = "wrap"; $0.speed = 0; $0.easing = .snap },
                KF.normal(at: 2.8)
            ], journalSummary: "Sudden zoomies. Full speed across the bar and back. Then groomed.")
        }
    )

    // MARK: - #28 Knocking Things Off

    static let knockingThingsOff = SurpriseDefinition(
        id: 28, name: "Knocking Things Off", category: .cat,
        stageMin: .critter, weight: 0.8,
        cooldown: 900, duration: 6.0,
        isEligible: { ctx in !ctx.placedObjects.isEmpty },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "neutral"; $0.body = "walk"; $0.speed = 10 },
                kf(1.0, 1.0) { $0.eyes = "stare"; $0.ears = "neutral"; $0.body = "stand"; $0.speed = 0 },
                kf(2.0, 0.5) { $0.paws = ["fl": "tap", "fr": "ground", "bl": "ground", "br": "ground"] },
                kf(2.5, 0.5) { $0.eyes = "stare"; $0.paws = ["fl": "push", "fr": "ground", "bl": "ground", "br": "ground"] },
                kf(3.0, 1.5) { $0.eyes = "watching_down"; $0.ears = "perk"; $0.body = "lean_forward" },
                kf(4.5, 1.0) { $0.eyes = "neutral"; $0.ears = "neutral"; $0.body = "stand"; $0.tail = "sway" },
                KF.normal(at: 5.5)
            ], journalSummary: "Walked to an object. Looked at user. Pushed it off. No remorse.")
        }
    )

    // MARK: - #29 If I Fits I Sits

    static let ifIFitsISits = SurpriseDefinition(
        id: 29, name: "If I Fits I Sits", category: .cat,
        stageMin: .critter, weight: 0.6,
        cooldown: 1200, duration: 30.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "focused"; $0.body = "walk"; $0.speed = 8 },
                kf(1.0, 2.0) { $0.eyes = "squint"; $0.ears = "flat"; $0.body = "squeeze"; $0.tail = "wrap" },
                kf(3.0, 25.0) { $0.eyes = "half"; $0.ears = "relaxed"; $0.body = "loaf"; $0.tail = "wrap"; $0.paws = ["fl": "tuck", "fr": "tuck", "bl": "tuck", "br": "tuck"] },
                KF.normal(at: 28.0)
            ], journalSummary: "Found the smallest possible gap. Squeezed in. Stayed for ages.")
        }
    )

    // MARK: - #30 Tail Chasing

    static let tailChasing = SurpriseDefinition(
        id: 30, name: "Tail Chasing", category: .cat,
        stageMin: .critter, weight: 0.9,
        cooldown: 600, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.tail = "twitch"; $0.body = "look_back" },
                kf(0.5, 0.5) { $0.body = "spin"; $0.speed = 30 },
                kf(1.0, 0.5) { $0.body = "spin"; $0.speed = 50 },
                kf(1.5, 0.5) { $0.body = "spin"; $0.speed = 70 },
                kf(2.0, 0.5) { $0.eyes = "triumphant"; $0.mouth = "bite"; $0.body = "stand"; $0.tail = "caught"; $0.speed = 0 },
                kf(2.5, 1.0) { $0.eyes = "neutral"; $0.mouth = "closed"; $0.body = "groom"; $0.tail = "sway" },
                KF.normal(at: 3.5)
            ], journalSummary: "Chased own tail. Caught it. Acted like it never happened.")
        }
    )

    // MARK: - #31 Chattering

    static let chattering = SurpriseDefinition(
        id: 31, name: "Chattering", category: .cat,
        stageMin: .critter, weight: 0.7,
        cooldown: 600, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.tail = "still" },
                kf(0.5, 3.0) { $0.eyes = "locked_up"; $0.ears = "perk"; $0.mouth = "chatter"; $0.tail = "twitch"; $0.whiskers = "forward"; $0.body = "tense" },
                kf(3.5, 1.0) { $0.eyes = "disappointed"; $0.ears = "droop"; $0.mouth = "lick"; $0.body = "stand" },
                KF.normal(at: 4.5)
            ], journalSummary: "Something flew overhead. The chattering was intense. It escaped.")
        }
    )

    // MARK: - #32 Kneading Session

    static let kneadingSession = SurpriseDefinition(
        id: 32, name: "Kneading Session", category: .cat,
        stageMin: .critter, weight: 0.8,
        cooldown: 600, duration: 10.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "walk"; $0.speed = 5 },
                kf(1.0, 3.0) { $0.eyes = "half"; $0.ears = "relaxed"; $0.body = "knead"; $0.paws = ["fl": "knead", "fr": "knead", "bl": "ground", "br": "ground"] },
                kf(4.0, 4.0) { $0.eyes = "closed"; $0.ears = "relaxed"; $0.body = "knead"; $0.mouth = "purr" },
                kf(8.0, 1.5) { $0.eyes = "closed"; $0.ears = "relaxed"; $0.body = "loaf" },
                KF.normal(at: 9.5)
            ], journalSummary: "Found a spot. Kneaded for ages. Pure contentment.")
        }
    )

    // MARK: - #33 The Loaf

    static let theLoaf = SurpriseDefinition(
        id: 33, name: "The Loaf", category: .cat,
        stageMin: .critter, weight: 1.0,
        cooldown: 600, duration: 45.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "loaf_prep"; $0.paws = ["fl": "tuck", "fr": "tuck", "bl": "tuck", "br": "tuck"] },
                kf(1.0, 40.0) { $0.eyes = "smug"; $0.ears = "relaxed"; $0.body = "loaf"; $0.tail = "wrap"; $0.paws = ["fl": "tuck", "fr": "tuck", "bl": "tuck", "br": "tuck"] },
                kf(41.0, 2.0) { $0.eyes = "half"; $0.body = "stand" },
                KF.normal(at: 43.0)
            ], journalSummary: "Achieved perfect loaf form. Smug about it for 45 seconds.")
        }
    )

    // MARK: - #34 Head in Box

    static let headInBox = SurpriseDefinition(
        id: 34, name: "Head in Box", category: .cat,
        stageMin: .critter, weight: 0.7,
        cooldown: 900, duration: 12.0,
        isEligible: { ctx in ctx.placedObjects.contains("cardboard_box") },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "walk"; $0.speed = 10 },
                kf(1.0, 1.0) { $0.body = "lean_forward"; $0.ears = "flat" },
                kf(2.0, 8.0) { $0.body = "head_in_box"; $0.tail = "sway_slow"; $0.eyes = "none" },
                kf(10.0, 1.5) { $0.body = "stand"; $0.eyes = "neutral"; $0.ears = "neutral"; $0.tail = "sway" },
                KF.normal(at: 11.5)
            ], journalSummary: "Put head in box. Stayed like that. Emerged normally.")
        }
    )

    // MARK: - #35 Gift Delivery

    static let giftDelivery = SurpriseDefinition(
        id: 35, name: "Gift Delivery", category: .cat,
        stageMin: .beast, weight: 0.5,
        cooldown: 1200, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.body = "run"; $0.speed = 40; $0.ears = "flat" },
                kf(1.5, 0.5) { $0.body = "pounce"; $0.mouth = "bite" },
                kf(2.0, 3.0) { $0.body = "walk"; $0.speed = 8; $0.mouth = "carrying"; $0.tail = "high" },
                kf(5.0, 2.5) { $0.eyes = "hopeful"; $0.ears = "perk"; $0.mouth = "open_small"; $0.tail = "sway"; $0.speech = "for you."; $0.speechStyle = .whisper },
                KF.normal(at: 7.5)
            ], journalSummary: "Caught something. Carried it to user. 'For you.'")
        }
    )

    // MARK: - #36 Butt Wiggle

    static let buttWiggle = SurpriseDefinition(
        id: 36, name: "Butt Wiggle", category: .cat,
        stageMin: .critter, weight: 1.2,
        cooldown: 300, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "narrow"; $0.ears = "flat"; $0.body = "crouch"; $0.tail = "low" },
                kf(0.5, 1.5) { $0.eyes = "narrow"; $0.ears = "flat"; $0.body = "wiggle"; $0.tail = "wiggle" },
                kf(2.0, 0.5) { $0.eyes = "wide"; $0.body = "pounce"; $0.easing = .snap },
                kf(2.5, 1.0) { $0.eyes = "confused"; $0.ears = "neutral"; $0.body = "stand" },
                KF.normal(at: 3.5)
            ], journalSummary: "Wiggled butt. Pounced. There was nothing there. Cat.")
        }
    )

    // MARK: - #37 Whisker Twitch

    static let whiskerTwitch = SurpriseDefinition(
        id: 37, name: "Whisker Twitch", category: .cat,
        stageMin: .drop, weight: 1.5,
        cooldown: 300, duration: 3.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.whiskers = "twitch_left" },
                kf(0.5, 0.5) { $0.whiskers = "twitch_right" },
                kf(1.0, 1.5) { $0.eyes = "tracking"; $0.whiskers = "forward" },
                KF.normal(at: 2.5)
            ], journalSummary: "Whiskers twitched. Tracking something only it can see.")
        }
    )

    // MARK: - #38 Belly Trap

    static let slowRollBellyTrap = SurpriseDefinition(
        id: 38, name: "Belly Trap", category: .cat,
        stageMin: .beast, weight: 0.6,
        cooldown: 900, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.body = "roll_onto_back"; $0.tail = "sway_slow" },
                kf(2.0, 5.0) { $0.eyes = "soft"; $0.ears = "relaxed"; $0.body = "belly_up"; $0.tail = "sway_slow"; $0.paws = ["fl": "curl", "fr": "curl", "bl": "relax", "br": "relax"] },
                KF.normal(at: 7.0)
            ], journalSummary: "Rolled over. Exposed belly. It was a trap.")
        }
    )

    // MARK: - #39 Perching

    static let perching = SurpriseDefinition(
        id: 39, name: "Perching", category: .cat,
        stageMin: .critter, weight: 0.6,
        cooldown: 900, duration: 20.0,
        isEligible: { ctx in !ctx.placedObjects.isEmpty },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.body = "jump"; $0.ears = "perk" },
                kf(0.5, 17.0) { $0.eyes = "regal"; $0.ears = "perk"; $0.body = "sit_high"; $0.tail = "hang_sway" },
                kf(17.5, 1.0) { $0.body = "jump_down" },
                KF.normal(at: 18.5)
            ], journalSummary: "Climbed to the highest point. Surveyed the domain.")
        }
    )

    // MARK: - #40 Bread-Making

    static let breadMaking = SurpriseDefinition(
        id: 40, name: "Bread-Making", category: .cat,
        stageMin: .beast, weight: 0.5,
        cooldown: 1200, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 5.0) { $0.eyes = "focused"; $0.ears = "neutral"; $0.body = "knead"; $0.paws = ["fl": "knead", "fr": "knead", "bl": "ground", "br": "ground"] },
                kf(5.0, 1.5) { $0.eyes = "proud"; $0.body = "lean_forward" },
                kf(6.5, 1.0) { $0.eyes = "neutral"; $0.body = "stand" },
                KF.normal(at: 7.5)
            ], journalSummary: "Made bread through kneading. It was not real bread.")
        }
    )

    // MARK: - #41 Midnight Crazies

    static let midnightCrazies = SurpriseDefinition(
        id: 41, name: "Midnight Crazies", category: .cat,
        stageMin: .critter, weight: 1.0,
        cooldown: 3600, duration: 6.0,
        isEligible: { ctx in
            let hour = Calendar.current.component(.hour, from: ctx.wallClock)
            return hour >= 23 || hour <= 2
        },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.8) { $0.body = "run"; $0.speed = 60; $0.eyes = "wide"; $0.easing = .snap },
                kf(0.8, 0.5) { $0.body = "jump"; $0.speed = 0 },
                kf(1.3, 0.5) { $0.body = "slide"; $0.speed = 30 },
                kf(1.8, 2.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "stand"; $0.tail = "poof"; $0.speed = 0 },
                kf(3.8, 0.5) { $0.body = "run"; $0.speed = 50; $0.easing = .snap },
                kf(4.3, 1.2) { $0.eyes = "wide"; $0.body = "stand"; $0.tail = "sway"; $0.speed = 0 },
                KF.normal(at: 5.5)
            ], journalSummary: "Midnight crazies. Run, jump, stop, stare at nothing.")
        }
    )

    // MARK: - #42 Tongue Blep

    static let tongueBlep = SurpriseDefinition(
        id: 42, name: "Tongue Blep", category: .cat,
        stageMin: .drop, weight: 1.5,
        cooldown: 600, duration: 45.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 43.0) { $0.mouth = "blep" },
                kf(43.0, 1.0) { $0.mouth = "closed" },
                KF.normal(at: 44.0)
            ], journalSummary: "Tongue blep. Out for 45 seconds. Never noticed.")
        }
    )
}
