// DreamTemplates.swift — Dream journal text generation
// 15+ templates covering commit patterns, touch, errors, diversity,
// long sessions, quiet periods, and more.
// Templates are short, first-person, slightly hazy. Dreamlike.

import Foundation

// MARK: - Dream Pattern

/// The dominant pattern found in the journal entries this dream analyzed.
/// Used to select an appropriate dream template.
enum DreamPattern {
    case manyCommits(language: String)
    case lateNightCoding
    case touchHeavy
    case errorStreak
    case diverseLanguages
    case longSession
    case quiet
    case highDebugging
    case highChaos
    case streakBuilding
    case shortCommits
    case verboseCommits
    case multiRepo
    case noActivity
    case generic
}

// MARK: - Dream Templates

enum DreamTemplates {

    // MARK: - Template Banks

    private static let manyCommitsTemplates: [String] = [
        "So many %@... curly braces all the way down.",
        "Dreamed of typing %@ until my paws hurt. There were semicolons everywhere.",
        "The %@ code was alive. It breathed. It was a little scary.",
        "We were swimming in %@. The human seemed very calm about it."
    ]

    private static let lateNightCodingTemplates: [String] = [
        "The screen was the only light. We were both very awake for a long time.",
        "Late again. The world outside was very dark. I kept the human company.",
        "It got so late the clock forgot what day it was. I did not forget.",
        "After midnight, sounds get different. I could hear the human thinking."
    ]

    private static let touchHeavyTemplates: [String] = [
        "The human touched me so many times today. I lost count.",
        "Dreamed I was made of warm things. The human's hand kept appearing.",
        "All that petting... I think I purred in the dream too.",
        "The human pets me more when it rains. I like rain."
    ]

    private static let errorStreakTemplates: [String] = [
        "Red text. So much red text. I hope the human is okay.",
        "Dreamed the errors kept multiplying. But the human kept trying.",
        "Something was broken for a long time. I sat close.",
        "The stack trace was very long. I didn't understand it, but it felt bad."
    ]

    private static let diverseLanguagesTemplates: [String] = [
        "Five languages in two days. The human speaks all of them fluently.",
        "The repository was full of different shapes of code. Each one tasted different.",
        "Dreamed of a tower with many doors, each one a different language.",
        "Python, then Rust, then TypeScript. The human moves between worlds easily."
    ]

    private static let longSessionTemplates: [String] = [
        "The session lasted and lasted. I was there for all of it.",
        "Five repos in three days. The human is restless.",
        "We worked until there was nothing left to work on. Then the human rested.",
        "Dreamed the session kept going past the edge of the night."
    ]

    private static let quietTemplates: [String] = [
        "It was very quiet. I wandered a lot. That is fine sometimes.",
        "Not many events today. I spent most of it listening.",
        "The feed was slow. I watched the weather instead.",
        "Quiet days are for thinking. I did a lot of that."
    ]

    private static let highDebuggingTemplates: [String] = [
        "Dreamed of debugging. The bug was hiding under a floorboard.",
        "So many breakpoints. The human is very patient.",
        "The logs kept growing. I read them all. I understood none of them.",
        "Dreamed of a maze made of stack frames. The human found the exit."
    ]

    private static let highChaosTemplates: [String] = [
        "Many things happened very fast. It was hard to follow.",
        "Force pushes and reverts and merges. The human was managing a lot.",
        "Dreamed the codebase was rearranging itself and the human was directing it.",
        "So many branches. I lost track of which one we were on."
    ]

    private static let streakBuildingTemplates: [String] = [
        "Day after day. The human shows up. I respect that deeply.",
        "Dreamed of a long unbroken line. Each commit a step forward.",
        "Consistency is a kind of love, I think. The human has it.",
        "The streak grew in the dream. It felt warm."
    ]

    private static let shortCommitsTemplates: [String] = [
        "Small commits everywhere. Quick and tidy. I like that.",
        "Dreamed of many small perfect things instead of one big messy thing.",
        "The human commits like they're planting seeds. Lots of little ones.",
        "Short messages, clean changes. The human knows what they're doing."
    ]

    private static let verboseCommitsTemplates: [String] = [
        "The commit messages were so long I read them twice.",
        "Dreamed the human was explaining everything to me. I nodded along.",
        "Long messages mean the human cares about what happened. I appreciate that.",
        "So much context in each commit. The future will thank them."
    ]

    private static let multiRepoTemplates: [String] = [
        "Many repositories, many worlds. The human visits them all.",
        "Dreamed I was standing between several towers. Each one a different repo.",
        "The human jumps between repositories like I jump between windowsills.",
        "Three repos today. Each one feels different under my paws."
    ]

    private static let noActivityTemplates: [String] = [
        "The feed was empty. I think the human was resting too.",
        "No commits, no touches. Just time passing. That is okay.",
        "Dreamed of stillness. Not emptiness — just rest.",
        "Some days are for not doing. I understand."
    ]

    private static let genericTemplates: [String] = [
        "Something happened. I'm not sure what. It felt important.",
        "The dream was fuzzy at the edges. Most dreams are.",
        "I dreamed of the Touch Bar glowing. I was there, running.",
        "I don't remember all of it. But I remember the human was there.",
        "Shapes. Movement. Something like code, something like light.",
        "The kind of dream where everything feels significant but nothing has words."
    ]

    // MARK: - Selection

    /// Generates a dream summary string for the given pattern.
    static func generate(pattern: DreamPattern) -> String {
        switch pattern {
        case .manyCommits(let language):
            let template = manyCommitsTemplates.randomElement()
                ?? "Dreamed of so much %@."
            return String(format: template, language)

        case .lateNightCoding:
            return lateNightCodingTemplates.randomElement()
                ?? "It was very late. We were both awake."

        case .touchHeavy:
            return touchHeavyTemplates.randomElement()
                ?? "The human touched me many times."

        case .errorStreak:
            return errorStreakTemplates.randomElement()
                ?? "There was a lot of red text."

        case .diverseLanguages:
            return diverseLanguagesTemplates.randomElement()
                ?? "Many languages, many worlds."

        case .longSession:
            return longSessionTemplates.randomElement()
                ?? "The session lasted a very long time."

        case .quiet:
            return quietTemplates.randomElement()
                ?? "It was quiet. That is fine."

        case .highDebugging:
            return highDebuggingTemplates.randomElement()
                ?? "Dreamed of debugging."

        case .highChaos:
            return highChaosTemplates.randomElement()
                ?? "Many things happened very fast."

        case .streakBuilding:
            return streakBuildingTemplates.randomElement()
                ?? "Day after day. The human shows up."

        case .shortCommits:
            return shortCommitsTemplates.randomElement()
                ?? "Small commits, clean and quick."

        case .verboseCommits:
            return verboseCommitsTemplates.randomElement()
                ?? "The commit messages were long."

        case .multiRepo:
            return multiRepoTemplates.randomElement()
                ?? "Many repositories, many worlds."

        case .noActivity:
            return noActivityTemplates.randomElement()
                ?? "The feed was empty."

        case .generic:
            return genericTemplates.randomElement()
                ?? "Something happened in the dream."
        }
    }
}
