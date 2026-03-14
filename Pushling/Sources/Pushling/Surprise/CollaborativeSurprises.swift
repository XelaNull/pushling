// CollaborativeSurprises.swift — Surprises #73-78: human+AI synchronicity

import Foundation
import CoreGraphics

enum CollaborativeSurprises {

    static let all: [SurpriseDefinition] = [
        theDuet, coDiscovery, giftReturn,
        groupNap, simultaneousTouch, teachingMoment
    ]

    static let theDuet = SurpriseDefinition(
        id: 73, name: "The Duet", category: .collaborative,
        stageMin: .beast, weight: 0.0, cooldown: 3600, duration: 10.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 3.0) { $0.eyes = "happy"; $0.ears = "perk"; $0.body = "sing"; $0.mouth = "sing" },
                kf(3.0, 4.0) { $0.body = "dance_frame_1"; $0.tail = "sway" },
                kf(7.0, 1.5) { $0.eyes = "wide"; $0.body = "celebrate" },
                kf(8.5, 1.0) { $0.eyes = "soft"; $0.speech = "we made music!"; $0.speechStyle = .exclaim },
                KF.normal(at: 9.5)
            ], journalSummary: "A duet! Claude sang, human tapped, creature danced.")
        }
    )

    static let coDiscovery = SurpriseDefinition(
        id: 74, name: "Co-Discovery", category: .collaborative,
        stageMin: .critter, weight: 0.0, cooldown: 3600, duration: 4.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "glow"; $0.tail = "high"; $0.speech = "TEAMWORK!"; $0.speechStyle = .exclaim },
                kf(2.5, 1.0) { $0.body = "co_glow" },
                KF.normal(at: 3.5)
            ], journalSummary: "Claude and human on the same file! 'TEAMWORK!'")
        }
    )

    static let giftReturn = SurpriseDefinition(
        id: 75, name: "Gift Return", category: .collaborative,
        stageMin: .critter, weight: 0.0, cooldown: 3600, duration: 5.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "pick_up"; $0.paws = ["fl": "grab", "fr": "grab", "bl": "ground", "br": "ground"] },
                kf(1.0, 2.0) { $0.body = "walk"; $0.mouth = "carrying"; $0.speed = 8 },
                kf(3.0, 1.5) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "push_forward"; $0.speech = "for you."; $0.speechStyle = .whisper },
                KF.normal(at: 4.5)
            ], journalSummary: "Gave an object to the user. 'For you.'")
        }
    )

    static let groupNap = SurpriseDefinition(
        id: 76, name: "Group Nap", category: .collaborative,
        stageMin: .critter, weight: 0.5, cooldown: 7200, duration: 10.0,
        isEligible: { ctx in
            let h = Calendar.current.component(.hour, from: ctx.wallClock)
            guard h >= 23 || h <= 3, ctx.isClaudeSessionActive else { return false }
            if let lt = ctx.lastTouchTimestamp { return ctx.wallClock.timeIntervalSince(lt) >= 300 }
            return true
        },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "dim_environment" },
                kf(1.0, 7.0) { $0.eyes = "closed"; $0.ears = "droop"; $0.body = "sleep_curl"; $0.tail = "wrap"; $0.paws = ["fl": "tuck", "fr": "tuck", "bl": "tuck", "br": "tuck"] },
                KF.say("zzz", at: 3.0, hold: 3.0, style: .dream),
                KF.normal(at: 8.0)
            ], journalSummary: "Late night group nap. Everyone fell asleep together.")
        }
    )

    static let simultaneousTouch = SurpriseDefinition(
        id: 77, name: "Simultaneous Touch", category: .collaborative,
        stageMin: .critter, weight: 0.0, cooldown: 1800, duration: 3.0,
        isEligible: { ctx in
            guard let lt = ctx.lastTouchTimestamp, let lm = ctx.lastMCPTimestamp else { return false }
            return abs(lt.timeIntervalSince(lm)) < 0.1
        },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "wide"; $0.body = "dual_glow"; $0.tail = "high" },
                KF.normal(at: 2.5)
            ], journalSummary: "Simultaneous human+AI presence. A rare moment.")
        }
    )

    static let teachingMoment = SurpriseDefinition(
        id: 78, name: "Teaching Moment", category: .collaborative,
        stageMin: .critter, weight: 0.0, cooldown: 1800, duration: 4.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.body = "replay_trick" },
                kf(2.0, 1.5) { $0.eyes = "hopeful"; $0.ears = "perk"; $0.speech = "like this?"; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "AI taught, creature performed, human encouraged.")
        }
    )
}
