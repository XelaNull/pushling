// TimeSurprises.swift — Surprises #49-57: calendar and clock-based

import Foundation
import CoreGraphics

enum TimeSurprises {

    static let all: [SurpriseDefinition] = [
        newYears, halloween, piDay, creatureBirthday, solsticeEquinox,
        fridayThe13th, leapYearDay, developerAnniversary, fullMoon
    ]

    static let newYears = SurpriseDefinition(
        id: 49, name: "New Year's", category: .time,
        stageMin: .drop, weight: 3.0, cooldown: 86400, duration: 6.0,
        isEligible: { ctx in let c = Calendar.current; let m = c.component(.month, from: ctx.wallClock); let d = c.component(.day, from: ctx.wallClock); return (m == 1 && d == 1) || (m == 12 && d == 31 && c.component(.hour, from: ctx.wallClock) >= 22) },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                KF.say("3", at: 0, hold: 1.0),
                KF.say("2", at: 1.0, hold: 1.0),
                KF.say("1", at: 2.0, hold: 1.0),
                kf(3.0, 2.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "celebrate"; $0.speech = "!!!"; $0.speechStyle = .exclaim },
                KF.normal(at: 5.5)
            ], journalSummary: "Happy New Year!")
        }
    )

    static let halloween = SurpriseDefinition(
        id: 50, name: "Halloween", category: .time,
        stageMin: .drop, weight: 3.0, cooldown: 86400, duration: 4.0,
        isEligible: { ctx in let c = Calendar.current; return c.component(.month, from: ctx.wallClock) == 10 && c.component(.day, from: ctx.wallClock) == 31 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.body = "costume_transform" },
                kf(1.0, 2.5) { $0.eyes = "spooky"; $0.ears = "perk"; $0.body = "spooky_pose"; $0.speech = "boo"; $0.speechStyle = .whisper },
                KF.normal(at: 3.5)
            ], journalSummary: "Halloween! Put on a costume. Went 'boo.'")
        }
    )

    static let piDay = SurpriseDefinition(
        id: 51, name: "Pi Day", category: .time,
        stageMin: .critter, weight: 3.0, cooldown: 86400, duration: 25.0,
        isEligible: { ctx in let c = Calendar.current; return c.component(.month, from: ctx.wallClock) == 3 && c.component(.day, from: ctx.wallClock) == 14 },
        animation: { _ in
            let digits = ["3", ".", "1", "4", "1", "5", "9", "2", "6", "5", "3", "5", "8", "9", "7", "9", "3", "2", "3", "8"]
            var keyframes = digits.enumerated().map { i, d in KF.say(d, at: Double(i), hold: 0.8) }
            keyframes.append(kf(Double(digits.count), 2.0) { $0.eyes = "wide"; $0.ears = "back"; $0.body = "mind_blown"; $0.speech = "!!!"; $0.speechStyle = .exclaim })
            keyframes.append(KF.normal(at: Double(digits.count) + 2.0))
            return SurpriseAnimation(keyframes: keyframes, journalSummary: "Pi Day! Recited 20 digits.")
        }
    )

    static let creatureBirthday = SurpriseDefinition(
        id: 52, name: "Creature Birthday", category: .time,
        stageMin: .drop, weight: 5.0, cooldown: 86400, duration: 8.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 3.0) { $0.body = "montage_flash" },
                kf(3.0, 2.0) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "sit"; $0.speech = "happy birthday to me"; $0.speechStyle = .whisper },
                kf(5.0, 2.5) { $0.eyes = "soft"; $0.body = "celebrate" },
                KF.normal(at: 7.5)
            ], journalSummary: "Birthday! A tiny cake appeared.")
        }
    )

    static let solsticeEquinox = SurpriseDefinition(
        id: 53, name: "Solstice/Equinox", category: .time,
        stageMin: .critter, weight: 2.0, cooldown: 86400, duration: 5.0,
        isEligible: { ctx in let c = Calendar.current; let m = c.component(.month, from: ctx.wallClock); let d = c.component(.day, from: ctx.wallClock); return (m == 6 && d >= 20 && d <= 21) || (m == 12 && d >= 21 && d <= 22) || (m == 3 && d >= 19 && d <= 20) || (m == 9 && d >= 22 && d <= 23) },
        animation: { ctx in
            let m = Calendar.current.component(.month, from: ctx.wallClock)
            let body = m == 6 ? "bask" : m == 12 ? "huddle" : "meditate"
            return SurpriseAnimation(keyframes: [
                kf(0, 4.5) { $0.eyes = m == 12 ? "closed" : "half"; $0.ears = "relaxed"; $0.body = body; $0.tail = "wrap" },
                KF.normal(at: 4.5)
            ], journalSummary: "Solstice/equinox. Felt the turning of the season.")
        }
    )

    static let fridayThe13th = SurpriseDefinition(
        id: 54, name: "Friday the 13th", category: .time,
        stageMin: .critter, weight: 2.5, cooldown: 86400, duration: 4.0,
        isEligible: { ctx in let c = Calendar.current; return c.component(.weekday, from: ctx.wallClock) == 6 && c.component(.day, from: ctx.wallClock) == 13 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 1.0) { $0.eyes = "nervous"; $0.ears = "flat"; $0.body = "glitch"; $0.tail = "poof" },
                kf(1.0, 1.0) { $0.eyes = "nervous"; $0.body = "glitch_static" },
                kf(2.0, 1.5) { $0.eyes = "nervous"; $0.ears = "flat"; $0.body = "stand"; $0.speech = "...something's off"; $0.speechStyle = .whisper },
                KF.normal(at: 3.5)
            ], journalSummary: "Friday the 13th. Everything was slightly glitchy.")
        }
    )

    static let leapYearDay = SurpriseDefinition(
        id: 55, name: "Leap Year Day", category: .time,
        stageMin: .critter, weight: 5.0, cooldown: 86400, duration: 4.0,
        isEligible: { ctx in let c = Calendar.current; return c.component(.month, from: ctx.wallClock) == 2 && c.component(.day, from: ctx.wallClock) == 29 },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 3.5) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "ghost_echo"; $0.speech = "bonus day!"; $0.speechStyle = .exclaim },
                KF.normal(at: 3.5)
            ], journalSummary: "Leap day! Gained a ghost echo.")
        }
    )

    static let developerAnniversary = SurpriseDefinition(
        id: 56, name: "Developer Anniversary", category: .time,
        stageMin: .critter, weight: 3.0, cooldown: 86400, duration: 6.0,
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "soft"; $0.ears = "neutral"; $0.body = "sit"; $0.speech = "Happy code day."; $0.speechStyle = .say },
                kf(2.0, 3.5) { $0.eyes = "soft"; $0.body = "reminisce" },
                KF.normal(at: 5.5)
            ], journalSummary: "Developer anniversary. 'Happy code day.'")
        }
    )

    static let fullMoon = SurpriseDefinition(
        id: 57, name: "Full Moon", category: .time,
        stageMin: .critter, weight: 2.0, cooldown: 86400 * 28, duration: 4.0,
        isEligible: { ctx in Self.isFullMoon(date: ctx.wallClock) },
        animation: { _ in
            SurpriseAnimation(keyframes: [
                kf(0, 2.0) { $0.eyes = "wide"; $0.ears = "perk"; $0.body = "look_up" },
                kf(2.0, 1.5) { $0.eyes = "closed"; $0.ears = "back"; $0.mouth = "open_small"; $0.body = "howl"; $0.speech = "awoo"; $0.speechStyle = .whisper },
                KF.normal(at: 3.5)
            ], journalSummary: "Full moon. 'Awoo.'")
        }
    )

    static func isFullMoon(date: Date) -> Bool {
        let knownNewMoon = DateComponents(calendar: .current, timeZone: .init(identifier: "UTC"), year: 2024, month: 1, day: 11, hour: 11, minute: 57).date ?? date
        let lunarCycle: TimeInterval = 29.53 * 86400
        let halfCycle = lunarCycle / 2.0
        let tolerance: TimeInterval = 86400
        let elapsed = date.timeIntervalSince(knownNewMoon)
        let phaseOffset = elapsed.truncatingRemainder(dividingBy: lunarCycle)
        return abs(phaseOffset - halfCycle) < tolerance
    }
}
