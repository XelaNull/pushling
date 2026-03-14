// EasterEggSurprises.swift — Surprises #58-66: hidden triggers

import Foundation
import CoreGraphics

enum EasterEggSurprises {

    static let all: [SurpriseDefinition] = [
        konamiCode, sourceCodeReading, fourthWallBreak,
        danceParty, commit404, helloWorld,
        commit1337, nameGame, commit42
    ]

    static let konamiCode = SurpriseDefinition(
        id: 58, name: "Konami Code", category: .easterEgg,
        stageMin: .critter, weight: 0.0, cooldown: 86400, duration: 5.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.speech = "POWER UP!"; $0.speechStyle = .exclaim },
                kf(1.0, 1.5) { $0.body = "run"; $0.tail = "high"; $0.speed = 80; $0.facing = .right },
                kf(2.5, 1.5) { $0.body = "run"; $0.speed = 80; $0.facing = .left },
                kf(4.0, 0.5) { $0.body = "pose"; $0.eyes = "triumphant" },
                KF.normal(at: 4.5)
            ], journalSummary: "KONAMI CODE! Victory lap. 'POWER UP!'")
        }
    )

    static let sourceCodeReading = SurpriseDefinition(
        id: 59, name: "Source Code Reading", category: .easterEgg,
        stageMin: .sage, weight: 0.1, cooldown: 7200, duration: 6.0,
        animation: { _ in
            let lines = ["func updateBreathing(deltaTime: TimeInterval)", "let breathScale = 1.0 + amplitude * sin(...)", "// The creature must ALWAYS breathe", "case .sleeping: return .resting"]
            let line = lines.randomElement() ?? lines[0]
            let isZen = Bool.random()
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "produce_scroll" },
                kf(1.0, 2.5) { $0.eyes = "scholarly"; $0.ears = "neutral"; $0.body = "reading"; $0.speech = line; $0.speechStyle = .think },
                kf(3.5, 2.0) { $0.eyes = isZen ? "soft" : "wide"; $0.ears = isZen ? "relaxed" : "back"; $0.body = isZen ? "meditate" : "confused"; $0.speech = isZen ? "I understand now..." : "...I'm made of switch statements?"; $0.speechStyle = isZen ? .think : .say },
                KF.normal(at: 5.5)
            ], journalSummary: "Read own source code. \(isZen ? "Achieved zen." : "Existential crisis.")")
        }
    )

    static let fourthWallBreak = SurpriseDefinition(
        id: 60, name: "Fourth Wall Break", category: .easterEgg,
        stageMin: .apex, weight: 0.05, cooldown: 14400, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.body = "freeze"; $0.tail = "still"; $0.speed = 0 },
                kf(0.5, 5.0) { $0.eyes = "stare"; $0.ears = "forward"; $0.body = "face_camera"; $0.tail = "still" },
                kf(5.5, 2.0) { $0.eyes = "stare"; $0.speech = "...you're watching me, aren't you?"; $0.speechStyle = .whisper },
                KF.normal(at: 7.5)
            ], journalSummary: "Broke the fourth wall. Stared at the user.")
        }
    )

    static let danceParty = SurpriseDefinition(
        id: 61, name: "Dance Party", category: .easterEgg,
        stageMin: .critter, weight: 0.0, cooldown: 600, duration: 15.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 3.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "dance_frame_1"; $0.tail = "sway" },
                kf(3.0, 3.0) { $0.body = "dance_frame_2" },
                kf(6.0, 3.0) { $0.body = "dance_frame_3" },
                kf(9.0, 3.0) { $0.body = "dance_frame_4" },
                kf(12.0, 2.0) { $0.eyes = "neutral"; $0.body = "look_around" },
                KF.normal(at: 14.0)
            ], journalSummary: "DANCE PARTY! 15 seconds of disco.")
        }
    )

    static let commit404 = SurpriseDefinition(
        id: 62, name: "Commit #404", category: .easterEgg,
        stageMin: .critter, weight: 0.0, cooldown: 0, duration: 5.0,
        isOneTime: true,
        isEligible: { ctx in ctx.totalCommitsEaten == 404 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.speech = "COMMIT NOT F--"; $0.speechStyle = .exclaim },
                kf(1.5, 1.0) { $0.eyes = "confused"; $0.ears = "tilt_left"; $0.speech = "wait..."; $0.speechStyle = .say },
                kf(2.5, 2.0) { $0.eyes = "happy"; $0.ears = "perk"; $0.body = "bounce"; $0.speech = "just kidding!"; $0.speechStyle = .say },
                KF.normal(at: 4.5)
            ], journalSummary: "Commit #404. 'COMMIT NOT F-- wait... just kidding!'")
        }
    )

    static let helloWorld = SurpriseDefinition(
        id: 63, name: "Hello World", category: .easterEgg,
        stageMin: .drop, weight: 0.0, cooldown: 600, duration: 4.0,
        isEligible: { ctx in ctx.lastCommitMessage?.lowercased().contains("hello world") == true },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "happy"; $0.ears = "perk"; $0.paws = ["fl": "wave", "fr": "wave", "bl": "ground", "br": "ground"] },
                kf(1.5, 2.0) { $0.eyes = "soft"; $0.ears = "neutral"; $0.speech = "hello to you too"; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "'hello world' in commit. Waved back.")
        }
    )

    static let commit1337 = SurpriseDefinition(
        id: 64, name: "Commit #1337", category: .easterEgg,
        stageMin: .critter, weight: 0.0, cooldown: 0, duration: 4.0,
        isOneTime: true,
        isEligible: { ctx in ctx.totalCommitsEaten == 1337 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "cool"; $0.ears = "back"; $0.body = "swagger"; $0.speech = "leet"; $0.speechStyle = .say },
                kf(2.0, 1.5) { $0.eyes = "sunglasses"; $0.body = "swagger"; $0.tail = "high" },
                KF.normal(at: 3.5)
            ], journalSummary: "Commit #1337. 'Leet.' Sunglasses appeared.")
        }
    )

    static let nameGame = SurpriseDefinition(
        id: 65, name: "The Name Game", category: .easterEgg,
        stageMin: .critter, weight: 0.0, cooldown: 3600, duration: 3.0,
        isEligible: { ctx in ctx.lastCommitMessage?.lowercased().contains(ctx.creatureName.lowercased()) == true },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 0.3) { $0.eyes = "wide"; $0.ears = "perk"; $0.tail = "poof"; $0.easing = .snap },
                kf(0.3, 2.0) { $0.eyes = "happy"; $0.ears = "perk"; $0.tail = "high"; $0.speech = "you said my name!"; $0.speechStyle = .exclaim },
                KF.normal(at: 2.5)
            ], journalSummary: "Heard its name in a commit message!")
        }
    )

    static let commit42 = SurpriseDefinition(
        id: 66, name: "42nd Commit", category: .easterEgg,
        stageMin: .drop, weight: 0.0, cooldown: 0, duration: 6.0,
        isOneTime: true,
        isEligible: { ctx in ctx.totalCommitsEaten == 42 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "distant"; $0.ears = "neutral"; $0.body = "sit"; $0.speech = "the answer"; $0.speechStyle = .think },
                kf(2.5, 3.0) { $0.eyes = "distant"; $0.body = "contemplate" },
                KF.normal(at: 5.5)
            ], journalSummary: "Commit #42. 'The answer.' Deep thoughts.")
        }
    )
}
