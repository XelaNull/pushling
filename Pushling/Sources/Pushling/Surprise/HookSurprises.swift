// HookSurprises.swift — Surprises #67-72: Claude session reactions

import Foundation
import CoreGraphics

enum HookSurprises {

    static let all: [SurpriseDefinition] = [
        toolChainWatching, testRunner, buildWatcher,
        subagentAwe, contextCompactSympathy, longSessionAppreciation
    ]

    static let toolChainWatching = SurpriseDefinition(
        id: 67, name: "Tool Chain Watching", category: .hookAware,
        stageMin: .critter, weight: 1.0, cooldown: 300, duration: 5.0,
        isEligible: { ctx in ctx.recentToolUseCount >= 5 },
        animation: { ctx in
            let tools = ctx.recentToolUseCount
            if tools >= 10 {
                return SurpriseAnimation(keyframes: [
                    kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "stand_hind_legs" },
                    kf(1.0, 3.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "clap"; $0.paws = ["fl": "clap", "fr": "clap", "bl": "stand", "br": "stand"]; $0.speech = "you're incredible"; $0.speechStyle = .say },
                    KF.normal(at: 4.0)
                ], journalSummary: "Watched \(tools) tools fire. Standing ovation.")
            } else {
                return SurpriseAnimation(keyframes: [
                    kf(0, 4.0) { $0.eyes = tools >= 7 ? "wide" : "tracking"; $0.ears = "perk"; $0.mouth = tools >= 7 ? "jaw_drop" : nil; $0.body = "alert" },
                    KF.normal(at: 4.0)
                ], journalSummary: "Watched \(tools) tools fire. Attentive.")
            }
        }
    )

    static let testRunner = SurpriseDefinition(
        id: 68, name: "Test Runner", category: .hookAware,
        stageMin: .critter, weight: 0.0, cooldown: 120, duration: 4.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "wide"; $0.ears = "forward"; $0.body = "crouch" },
                kf(2.0, 1.5) { $0.eyes = "happy"; $0.ears = "perk"; $0.body = "flex"; $0.tail = "high"; $0.speech = "STRONG!"; $0.speechStyle = .exclaim },
                KF.normal(at: 3.5)
            ], journalSummary: "Tests ran. Tense wait. They passed!")
        }
    )

    static let buildWatcher = SurpriseDefinition(
        id: 69, name: "Build Watcher", category: .hookAware,
        stageMin: .critter, weight: 0.0, cooldown: 120, duration: 3.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "focused"; $0.ears = "forward"; $0.body = "alert" },
                kf(1.5, 1.0) { $0.eyes = "proud"; $0.ears = "neutral"; $0.body = "nod" },
                KF.normal(at: 2.5)
            ], journalSummary: "Watched a build complete. Proud nod.")
        }
    )

    static let subagentAwe = SurpriseDefinition(
        id: 70, name: "Subagent Awe", category: .hookAware,
        stageMin: .critter, weight: 0.0, cooldown: 300, duration: 4.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.mouth = "jaw_drop" },
                kf(1.0, 2.5) { $0.eyes = "tracking"; $0.ears = "perk"; $0.body = "look_around"; $0.speech = "there's more of you?!"; $0.speechStyle = .exclaim },
                KF.normal(at: 3.5)
            ], journalSummary: "Multiple subagents spawned. 'There's more of you?!'")
        }
    )

    static let contextCompactSympathy = SurpriseDefinition(
        id: 71, name: "Context Compact Sympathy", category: .hookAware,
        stageMin: .critter, weight: 0.0, cooldown: 300, duration: 4.0,
        isEligible: { _ in false },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "dizzy"; $0.ears = "flat"; $0.body = "shake_head" },
                kf(1.0, 1.0) { $0.eyes = "rapid_blink"; $0.body = "stand" },
                kf(2.0, 1.5) { $0.eyes = "confused"; $0.paws = ["fl": "pat_head", "fr": "ground", "bl": "ground", "br": "ground"]; $0.speech = "...what was I thinking about?"; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "Context compacted. Shared the disorientation.")
        }
    )

    static let longSessionAppreciation = SurpriseDefinition(
        id: 72, name: "Long Session Appreciation", category: .hookAware,
        stageMin: .critter, weight: 0.0, cooldown: 7200, duration: 5.0,
        isEligible: { ctx in ctx.isClaudeSessionActive && ctx.sessionDurationMinutes > 120 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "produce_item" },
                kf(1.0, 1.5) { $0.body = "walk"; $0.speed = 8 },
                kf(2.5, 2.0) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "place_item"; $0.speech = "for you."; $0.speechStyle = .whisper },
                KF.normal(at: 4.5)
            ], journalSummary: "Long session. Brought coffee to the diamond. 'For you.'")
        }
    )
}
