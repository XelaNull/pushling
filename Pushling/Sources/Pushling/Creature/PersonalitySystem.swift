// PersonalitySystem.swift — 5 personality axes defining the creature's character
// Loaded from SQLite on launch, cached in memory, drifts slowly with ongoing commits.
//
// Axes:
//   Energy      0.0 (calm) to 1.0 (hyperactive) — commit frequency/bursts
//   Verbosity   0.0 (stoic) to 1.0 (chatty)     — message length/quality
//   Focus       0.0 (scattered) to 1.0 (deliberate) — files per commit, repo switching
//   Discipline  0.0 (chaotic) to 1.0 (methodical)  — commit timing regularity
//   Specialty   LanguageCategory enum             — dominant file extensions
//
// Personality is NOT emotion. Personality is who the creature IS (changes over weeks).
// Emotion is how the creature FEELS (changes over minutes).

import Foundation

// MARK: - Language Category

/// Language specialty categories derived from file extensions.
/// Determines subtle visual and movement modifiers.
enum LanguageCategory: String, Codable, CaseIterable {
    case systems     // .rs, .c, .cpp, .go, .zig, .h, .hpp
    case frontend    // .tsx, .jsx, .vue, .svelte, .css, .scss, .html
    case backend     // .php, .rb, .erb, .blade.php, .twig
    case script      // .py, .sh, .bash, .lua, .pl, .r
    case jvm         // .java, .kt, .scala, .groovy, .clj
    case mobile      // .swift, .m, .dart, .xml (android)
    case data        // .sql, .csv, .ipynb, .parquet
    case infra       // .yaml, .yml, .tf, .dockerfile, .nix, .toml, .hcl
    case docs        // .md, .txt, .rst, .tex, .adoc
    case config      // .json, .xml, .ini, .env, .properties
    case polyglot    // No category >30%

    /// Map file extensions to categories.
    static let extensionMap: [String: LanguageCategory] = [
        // Systems
        "rs": .systems, "c": .systems, "cpp": .systems, "go": .systems,
        "zig": .systems, "h": .systems, "hpp": .systems, "cc": .systems,
        // Frontend
        "tsx": .frontend, "jsx": .frontend, "vue": .frontend,
        "svelte": .frontend, "css": .frontend, "scss": .frontend,
        "html": .frontend, "less": .frontend, "sass": .frontend,
        // Backend
        "php": .backend, "rb": .backend, "erb": .backend,
        // Script
        "py": .script, "sh": .script, "bash": .script, "lua": .script,
        "pl": .script, "r": .script, "zsh": .script,
        // JVM
        "java": .jvm, "kt": .jvm, "scala": .jvm,
        "groovy": .jvm, "clj": .jvm,
        // Mobile
        "swift": .mobile, "m": .mobile, "dart": .mobile,
        // Data
        "sql": .data, "csv": .data, "ipynb": .data, "parquet": .data,
        // Infra
        "yaml": .infra, "yml": .infra, "tf": .infra,
        "dockerfile": .infra, "nix": .infra, "toml": .infra,
        "hcl": .infra,
        // Docs
        "md": .docs, "txt": .docs, "rst": .docs,
        "tex": .docs, "adoc": .docs,
        // Config
        "json": .config, "xml": .config, "ini": .config,
        "env": .config, "properties": .config,
    ]

    /// Hue value (0.0-1.0) for creature base color.
    var baseColorHue: Double {
        switch self {
        case .systems:  return 0.08   // orange
        case .frontend: return 0.15   // yellow
        case .backend:  return 0.75   // purple
        case .script:   return 0.45   // blue-green
        case .jvm:      return 0.58   // blue
        case .mobile:   return 0.05   // red-orange
        case .data:     return 0.55   // cyan-blue
        case .infra:    return 0.30   // green
        case .docs:     return 0.12   // warm yellow
        case .config:   return 0.60   // blue
        case .polyglot: return 0.50   // neutral teal
        }
    }
}

// MARK: - Personality

/// The 5 personality axes that define the creature's permanent character.
/// Loaded from SQLite, cached in memory, produces PersonalitySnapshot for
/// the behavior stack.
struct Personality: Codable {
    /// 0.0 (calm) to 1.0 (hyperactive) — commit frequency/bursts.
    var energy: Double

    /// 0.0 (stoic) to 1.0 (chatty) — message length/quality.
    var verbosity: Double

    /// 0.0 (scattered) to 1.0 (deliberate) — files per commit, repo switching.
    var focus: Double

    /// 0.0 (chaotic) to 1.0 (methodical) — commit timing regularity.
    var discipline: Double

    /// Category, not spectrum — dominant file extensions.
    var specialty: LanguageCategory

    /// Default neutral personality (all axes at 0.5, polyglot).
    static let neutral = Personality(
        energy: 0.5, verbosity: 0.5, focus: 0.5,
        discipline: 0.5, specialty: .polyglot
    )

    /// Convert to the lightweight snapshot used by the behavior stack.
    func toSnapshot() -> PersonalitySnapshot {
        PersonalitySnapshot(
            energy: energy,
            verbosity: verbosity,
            focus: focus,
            discipline: discipline
        )
    }

    /// Clamp all axes to valid [0, 1] range.
    mutating func clampAxes() {
        energy = clamp(energy, min: 0, max: 1)
        verbosity = clamp(verbosity, min: 0, max: 1)
        focus = clamp(focus, min: 0, max: 1)
        discipline = clamp(discipline, min: 0, max: 1)
    }
}

// MARK: - Visual Traits

/// Visual traits derived from git history. Stored in SQLite, applied during
/// creature rendering.
struct VisualTraits: Codable {
    /// Hue for creature body tint (0.0-1.0).
    var baseColorHue: Double

    /// Body proportion: lean (0.0) to round (1.0).
    var bodyProportion: Double

    /// Fur pattern based on repo count.
    var furPattern: FurPattern

    /// Tail shape based on primary language family.
    var tailShape: TailShape

    /// Eye shape based on commit message style.
    var eyeShape: EyeShape

    /// Default visual traits.
    static let neutral = VisualTraits(
        baseColorHue: 0.5,
        bodyProportion: 0.5,
        furPattern: .none,
        tailShape: .standard,
        eyeShape: .round
    )
}

// MARK: - Visual Trait Enums

enum FurPattern: String, Codable {
    case none      // 1-3 repos
    case spots     // 4-8 repos
    case stripes   // 9-15 repos
    case tabby     // 16+ repos

    static func fromRepoCount(_ count: Int) -> FurPattern {
        switch count {
        case 0...3:   return .none
        case 4...8:   return .spots
        case 9...15:  return .stripes
        default:      return .tabby
        }
    }
}

enum TailShape: String, Codable {
    case thin       // Systems languages — thin whip tail
    case fluffy     // Web languages — fluffy plume
    case serpentine // Script languages — serpentine curl
    case standard   // Everything else

    static func fromCategory(_ category: LanguageCategory) -> TailShape {
        switch category {
        case .systems:              return .thin
        case .frontend, .backend:   return .fluffy
        case .script:               return .serpentine
        default:                    return .standard
        }
    }
}

enum EyeShape: String, Codable {
    case round    // Verbose committers (avg > 50 chars)
    case standard // Mid-range
    case narrow   // Terse committers (avg < 20 chars)

    static func fromAverageMessageLength(_ avg: Double) -> EyeShape {
        if avg > 50 { return .round }
        if avg < 20 { return .narrow }
        return .standard
    }
}

// MARK: - Personality Persistence

/// Helpers for reading/writing personality from SQLite.
enum PersonalityPersistence {

    /// Load personality from the creature table.
    /// Returns `.neutral` if no creature exists.
    static func load(from db: DatabaseManager) -> Personality {
        do {
            let rows = try db.query(
                """
                SELECT energy_axis, verbosity_axis, focus_axis,
                       discipline_axis, specialty
                FROM creature WHERE id = 1
                """
            )
            guard let row = rows.first else { return .neutral }

            let energy = (row["energy_axis"] as? Double) ?? 0.5
            let verbosity = (row["verbosity_axis"] as? Double) ?? 0.5
            let focus = (row["focus_axis"] as? Double) ?? 0.5
            let discipline = (row["discipline_axis"] as? Double) ?? 0.5
            let specialtyStr = (row["specialty"] as? String) ?? "polyglot"
            let specialty = LanguageCategory(rawValue: specialtyStr) ?? .polyglot

            return Personality(
                energy: energy, verbosity: verbosity,
                focus: focus, discipline: discipline,
                specialty: specialty
            )
        } catch {
            NSLog("[Pushling/Personality] Failed to load: %@", "\(error)")
            return .neutral
        }
    }

    /// Save personality axes to the creature table.
    static func save(_ personality: Personality, to db: DatabaseManager) {
        do {
            try db.execute(
                """
                UPDATE creature SET
                    energy_axis = ?, verbosity_axis = ?,
                    focus_axis = ?, discipline_axis = ?,
                    specialty = ?
                WHERE id = 1
                """,
                arguments: [
                    personality.energy, personality.verbosity,
                    personality.focus, personality.discipline,
                    personality.specialty.rawValue
                ]
            )
        } catch {
            NSLog("[Pushling/Personality] Failed to save: %@", "\(error)")
        }
    }

    /// Load visual traits from the creature table.
    static func loadVisualTraits(from db: DatabaseManager) -> VisualTraits {
        do {
            let rows = try db.query(
                """
                SELECT base_color_hue, body_proportion, fur_pattern,
                       tail_shape, eye_shape
                FROM creature WHERE id = 1
                """
            )
            guard let row = rows.first else { return .neutral }

            let hue = (row["base_color_hue"] as? Double) ?? 0.5
            let proportion = (row["body_proportion"] as? Double) ?? 0.5
            let furStr = (row["fur_pattern"] as? String) ?? "none"
            let tailStr = (row["tail_shape"] as? String) ?? "standard"
            let eyeStr = (row["eye_shape"] as? String) ?? "round"

            return VisualTraits(
                baseColorHue: hue,
                bodyProportion: proportion,
                furPattern: FurPattern(rawValue: furStr) ?? .none,
                tailShape: TailShape(rawValue: tailStr) ?? .standard,
                eyeShape: EyeShape(rawValue: eyeStr) ?? .round
            )
        } catch {
            NSLog("[Pushling/Personality] Failed to load visual traits: %@",
                  "\(error)")
            return .neutral
        }
    }

    /// Save visual traits to the creature table.
    static func saveVisualTraits(_ traits: VisualTraits,
                                  to db: DatabaseManager) {
        do {
            try db.execute(
                """
                UPDATE creature SET
                    base_color_hue = ?, body_proportion = ?,
                    fur_pattern = ?, tail_shape = ?, eye_shape = ?
                WHERE id = 1
                """,
                arguments: [
                    traits.baseColorHue, traits.bodyProportion,
                    traits.furPattern.rawValue, traits.tailShape.rawValue,
                    traits.eyeShape.rawValue
                ]
            )
        } catch {
            NSLog("[Pushling/Personality] Failed to save visual traits: %@",
                  "\(error)")
        }
    }
}
