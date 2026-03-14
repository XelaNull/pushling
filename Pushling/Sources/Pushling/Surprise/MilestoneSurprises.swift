// MilestoneSurprises.swift — Surprises #43-48: life event ceremonies

import Foundation
import CoreGraphics

enum MilestoneSurprises {

    static let all: [SurpriseDefinition] = [
        newRepoDiscovery, commitMilestones, evolutionCeremony,
        firstMutation, firstWord, hundredthFileType
    ]

    static let newRepoDiscovery = SurpriseDefinition(
        id: 43, name: "New Repo Discovery", category: .milestone,
        stageMin: .drop, weight: 2.0, cooldown: 0, duration: 5.0,
        bypassesCooldown: true, suppressesOthers: true,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.tail = "high"; $0.speech = "NEW WORLD!"; $0.speechStyle = .exclaim },
                kf(2.0, 1.5) { $0.eyes = "wide"; $0.ears = "forward"; $0.body = "run"; $0.speed = 30 },
                kf(3.5, 1.0) { $0.eyes = "wide"; $0.ears = "forward"; $0.body = "stand"; $0.speed = 0 },
                KF.normal(at: 4.5)
            ], journalSummary: "Discovered a new repo! 'NEW WORLD!'")
        }
    )

    static let commitMilestones = SurpriseDefinition(
        id: 44, name: "Commit Milestones", category: .milestone,
        stageMin: .drop, weight: 2.0, cooldown: 0, duration: 6.0,
        bypassesCooldown: true, suppressesOthers: true,
        isEligible: { ctx in [100, 500, 1000, 5000].contains(ctx.totalCommitsEaten) },
        animation: { ctx in
            let c = ctx.totalCommitsEaten
            let speech = c == 100 ? "100!" : c == 500 ? "FIVE HUNDRED!" : c == 1000 ? "A THOUSAND!" : "..."
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert" },
                kf(1.0, 3.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = c >= 1000 ? "ascend" : "celebrate"; $0.tail = "high"; $0.speech = speech; $0.speechStyle = .exclaim },
                kf(4.0, 1.5) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "stand" },
                KF.normal(at: 5.5)
            ], journalSummary: "Commit milestone: \(c) commits eaten.")
        }
    )

    static let evolutionCeremony = SurpriseDefinition(
        id: 45, name: "Evolution Ceremony", category: .milestone,
        stageMin: .spore, weight: 10.0, cooldown: 0, duration: 5.0,
        bypassesCooldown: true, suppressesOthers: true,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 5.0) { $0.body = "evolving" },
                KF.normal(at: 5.0)
            ], journalSummary: "Evolution ceremony — a stage transition occurred.")
        }
    )

    static let firstMutation = SurpriseDefinition(
        id: 46, name: "First Mutation", category: .milestone,
        stageMin: .drop, weight: 5.0, cooldown: 0, duration: 5.0,
        bypassesCooldown: true, suppressesOthers: true, isOneTime: true,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "look_up" },
                kf(1.5, 1.5) { $0.eyes = "curious"; $0.ears = "forward"; $0.paws = ["fl": "reach_up", "fr": "ground", "bl": "ground", "br": "ground"] },
                kf(3.0, 1.5) { $0.eyes = "wide"; $0.body = "examine_self" },
                KF.normal(at: 4.5)
            ], journalSummary: "First mutation badge earned!")
        }
    )

    static let firstWord = SurpriseDefinition(
        id: 47, name: "First Word", category: .milestone,
        stageMin: .critter, weight: 10.0, cooldown: 0, duration: 5.0,
        bypassesCooldown: true, suppressesOthers: true, isOneTime: true,
        animation: { ctx in
            SurpriseAnimation(keyframes: [
                kf(0, 5.0) { $0.body = "first_word_ceremony" },
                KF.normal(at: 5.0)
            ], journalSummary: "Spoke for the first time: '...\(ctx.creatureName)?'")
        }
    )

    static let hundredthFileType = SurpriseDefinition(
        id: 48, name: "100th File Type", category: .milestone,
        stageMin: .beast, weight: 3.0, cooldown: 0, duration: 8.0,
        bypassesCooldown: true, suppressesOthers: true, isOneTime: true,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "distant"; $0.ears = "neutral"; $0.body = "sit"; $0.speech = "I've tasted everything..."; $0.speechStyle = .say },
                KF.say(".ts: 'my favorite'", at: 2.0, hold: 1.5, style: .think),
                KF.say(".css: 'dessert'", at: 3.5, hold: 1.0, style: .think),
                KF.say(".py: 'smooth'", at: 4.5, hold: 1.0, style: .think),
                KF.say(".json: 'crunchy'", at: 5.5, hold: 1.0, style: .think),
                KF.say(".md: 'nutritious'", at: 6.5, hold: 1.0, style: .think),
                KF.normal(at: 7.5)
            ], journalSummary: "100 unique file types tasted. Ranked them all.")
        }
    )
}
