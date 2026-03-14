// ContextualSurprises.swift — Surprises #13-26: reactions to developer activity

import Foundation
import CoreGraphics

enum ContextualSurprises {

    static let all: [SurpriseDefinition] = [
        branchCommentary, timeAwareness, commitEcho, languagePreference,
        streakCelebration, typingRhythmMirror, fileTypeCommentary,
        longFunction, mergeDay, dependencyUpdate, readmeEditing,
        branchSwitching, conflictResolution, testCoverage
    ]

    static let branchCommentary = SurpriseDefinition(
        id: 13, name: "Branch Commentary", category: .contextual,
        stageMin: .critter, weight: 0.9, cooldown: 600, duration: 3.0,
        isEligible: { ctx in ctx.lastCommitBranch != nil },
        animation: { ctx in
            let branch = ctx.lastCommitBranch ?? "main"
            let lower = branch.lowercased()
            let speech: String
            let earState: String
            if lower.hasPrefix("hotfix") || lower.hasPrefix("urgent") { speech = "urgent!"; earState = "flat" }
            else if lower.hasPrefix("yolo") || lower.contains("hack") { speech = "...brave"; earState = "back" }
            else if lower.hasPrefix("feature") { speech = "ooh, new!"; earState = "perk" }
            else { speech = "hmm"; earState = "tilt_left" }
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "curious"; $0.ears = "perk"; $0.body = "alert" },
                kf(1.0, 1.5) { $0.eyes = "curious"; $0.ears = earState; $0.speech = speech; $0.speechStyle = .say },
                KF.normal(at: 2.5)
            ], journalSummary: "Noticed branch '\(branch)'. Had opinions.")
        }
    )

    static let timeAwareness = SurpriseDefinition(
        id: 14, name: "Time Awareness", category: .contextual,
        stageMin: .critter, weight: 0.8, cooldown: 3600, duration: 4.0,
        isEligible: { ctx in
            let c = Calendar.current; let h = c.component(.hour, from: ctx.wallClock); let w = c.component(.weekday, from: ctx.wallClock)
            return (w == 6 && h >= 16 && h <= 18) || (w == 2 && h >= 8 && h <= 10) || (w == 4 && h == 12)
        },
        animation: { ctx in
            let w = Calendar.current.component(.weekday, from: ctx.wallClock)
            let speech = w == 6 ? "FRIDAY!" : w == 2 ? "...monday" : "halfway"
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "curious"; $0.body = "look_around" },
                kf(1.0, 2.5) { $0.eyes = w == 6 ? "wide" : "half"; $0.ears = w == 6 ? "perk" : "droop"; $0.speech = speech; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "Noticed the time. '\(speech)'")
        }
    )

    static let commitEcho = SurpriseDefinition(
        id: 15, name: "Commit Echo", category: .contextual,
        stageMin: .critter, weight: 0.7, cooldown: 1800, duration: 4.0,
        isEligible: { ctx in
            guard let ts = ctx.lastCommitTimestamp else { return false }
            let e = ctx.wallClock.timeIntervalSince(ts); return e >= 1800 && e <= 7200
        },
        animation: { ctx in
            let msg = String((ctx.lastCommitMessage ?? "something").prefix(30))
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "distant"; $0.body = "stand"; $0.speed = 0 },
                kf(1.0, 2.5) { $0.eyes = "distant"; $0.ears = "neutral"; $0.speech = msg; $0.speechStyle = .think },
                KF.normal(at: 3.5)
            ], journalSummary: "Still thinking about '\(msg)' from earlier.")
        }
    )

    static let languagePreference = SurpriseDefinition(
        id: 16, name: "Language Preference", category: .contextual,
        stageMin: .critter, weight: 0.8, cooldown: 900, duration: 3.0,
        isEligible: { ctx in ctx.lastCommitLanguages?.isEmpty == false },
        animation: { ctx in
            let lang = ctx.lastCommitLanguages?.first ?? "code"
            return SurpriseAnimation(keyframes: [
                kf(0, 0.5) { $0.eyes = "curious"; $0.ears = "perk" },
                kf(0.5, 2.0) { $0.eyes = "happy"; $0.ears = "perk"; $0.speech = ".\(lang)!"; $0.speechStyle = .say },
                KF.normal(at: 2.5)
            ], journalSummary: "Noticed a .\(lang) commit. Had feelings.")
        }
    )

    static let streakCelebration = SurpriseDefinition(
        id: 17, name: "Streak Celebration", category: .contextual,
        stageMin: .critter, weight: 1.5, cooldown: 86400, duration: 5.0,
        isEligible: { ctx in [7, 14, 30, 100].contains(ctx.streakDays) },
        animation: { ctx in
            let d = ctx.streakDays
            let speech = d == 7 ? "WEEK!" : d == 14 ? "TWO WEEKS!!" : d == 30 ? "LEGENDARY!!!" : "!!!!!!"
            return SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert"; $0.tail = "high" },
                kf(1.0, 3.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "celebrate"; $0.tail = "high"; $0.speech = speech; $0.speechStyle = .exclaim },
                KF.normal(at: 4.0)
            ], journalSummary: "\(d)-day streak! '\(speech)'")
        }
    )

    static let typingRhythmMirror = SurpriseDefinition(
        id: 18, name: "Typing Rhythm Mirror", category: .contextual,
        stageMin: .critter, weight: 0.5, cooldown: 600, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 4.5) { $0.body = "walk_rhythm"; $0.speed = 15 },
                KF.normal(at: 4.5)
            ], journalSummary: "Walked in tempo with typing rhythm.")
        }
    )

    static let fileTypeCommentary = SurpriseDefinition(
        id: 19, name: "File Type Commentary", category: .contextual,
        stageMin: .critter, weight: 0.7, cooldown: 900, duration: 3.0,
        isEligible: { ctx in ctx.lastCommitLanguages?.isEmpty == false },
        animation: { ctx in
            let lang = (ctx.lastCommitLanguages?.first ?? "").lowercased()
            let speech = lang.contains("css") ? "pretty!" : lang.contains("test") ? "STRONG" : ""
            let body = lang.contains("css") ? "groom" : lang.contains("test") ? "flex" : "stand"
            return SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "curious"; $0.body = body; if !speech.isEmpty { $0.speech = speech; $0.speechStyle = .say } },
                KF.normal(at: 2.5)
            ], journalSummary: "Commented on .\(lang) files.")
        }
    )

    static let longFunction = SurpriseDefinition(
        id: 20, name: "Long Function", category: .contextual,
        stageMin: .beast, weight: 0.6, cooldown: 1800, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "alert" },
                kf(1.0, 1.0) { $0.eyes = "exhausted"; $0.ears = "droop"; $0.body = "slouch" },
                kf(2.0, 1.5) { $0.eyes = "closed"; $0.mouth = "yawn"; $0.body = "slouch" },
                KF.normal(at: 3.5)
            ], journalSummary: "Read a very long function. Needed a moment.")
        }
    )

    static let mergeDay = SurpriseDefinition(
        id: 21, name: "Merge Day", category: .contextual,
        stageMin: .critter, weight: 0.8, cooldown: 3600, duration: 3.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "focused"; $0.ears = "perk"; $0.body = "construction" },
                KF.normal(at: 2.5)
            ], journalSummary: "Merge day. Put on a tiny hard hat.")
        }
    )

    static let dependencyUpdate = SurpriseDefinition(
        id: 22, name: "Dependency Update", category: .contextual,
        stageMin: .critter, weight: 0.7, cooldown: 1800, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.5) { $0.eyes = "focused"; $0.body = "examine" },
                kf(1.5, 1.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "balance_block"; $0.paws = ["fl": "hold", "fr": "hold", "bl": "ground", "br": "ground"] },
                kf(3.0, 1.0) { $0.eyes = "wide"; $0.mouth = "closed_tight"; $0.body = "freeze" },
                kf(4.0, 0.7) { $0.eyes = "relief"; $0.mouth = "exhale"; $0.body = "stand" },
                KF.normal(at: 4.7)
            ], journalSummary: "Balanced another dependency block. It held.")
        }
    )

    static let readmeEditing = SurpriseDefinition(
        id: 23, name: "README Editing", category: .contextual,
        stageMin: .critter, weight: 0.6, cooldown: 1800, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 3.5) { $0.eyes = "scholarly"; $0.ears = "neutral"; $0.body = "reading" },
                KF.normal(at: 3.5)
            ], journalSummary: "Put on tiny glasses. Read along with the documentation.")
        }
    )

    static let branchSwitching = SurpriseDefinition(
        id: 24, name: "Branch Switching", category: .contextual,
        stageMin: .critter, weight: 0.8, cooldown: 600, duration: 4.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "dizzy"; $0.ears = "droop"; $0.body = "stagger" },
                kf(1.0, 1.0) { $0.eyes = "spinning"; $0.body = "wobble" },
                kf(2.0, 1.5) { $0.eyes = "dizzy"; $0.body = "sit"; $0.speech = "...where am I?"; $0.speechStyle = .say },
                KF.normal(at: 3.5)
            ], journalSummary: "Too many branch switches. Dizzy.")
        }
    )

    static let conflictResolution = SurpriseDefinition(
        id: 25, name: "Conflict Resolution", category: .contextual,
        stageMin: .beast, weight: 0.6, cooldown: 1800, duration: 5.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "stand"; $0.facing = .left; $0.paws = ["fl": "gesture", "fr": "ground", "bl": "ground", "br": "ground"] },
                kf(1.0, 1.0) { $0.body = "stand"; $0.facing = .right; $0.paws = ["fl": "ground", "fr": "gesture", "bl": "ground", "br": "ground"] },
                kf(2.0, 1.0) { $0.paws = ["fl": "gesture", "fr": "gesture", "bl": "ground", "br": "ground"] },
                kf(3.0, 1.5) { $0.eyes = "soft"; $0.ears = "neutral"; $0.speech = "let's talk"; $0.speechStyle = .say },
                KF.normal(at: 4.5)
            ], journalSummary: "Mediated a merge conflict. Brought both sides together.")
        }
    )

    static let testCoverage = SurpriseDefinition(
        id: 26, name: "Test Coverage", category: .contextual,
        stageMin: .critter, weight: 0.7, cooldown: 1800, duration: 3.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.5) { $0.eyes = "proud"; $0.ears = "perk"; $0.body = "thumbs_up"; $0.tail = "high"; $0.speech = "strong!"; $0.speechStyle = .exclaim },
                KF.normal(at: 2.5)
            ], journalSummary: "Tests added! Gave a thumbs-up.")
        }
    )
}
