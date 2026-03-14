// WorldTinting.swift — Diet-influenced world color tinting
// Subtle color overlay (alpha 0.15-0.25) based on creature's language specialty.
// The tint makes each developer's Pushling world feel unique.
// Single SKSpriteNode overlay at high Z with blend mode .alpha.
//
// Tint transitions use a 10-second crossfade when specialty changes.
// Polyglot tint cycles smoothly between influences over 30s.
//
// Zero additional nodes — one overlay sprite.

import SpriteKit

// MARK: - Language Specialty

/// The language specialty categories that influence world tinting.
/// Maps to the creature's `specialty` field in SQLite.
enum LanguageSpecialty: String {
    case systems    // .rs, .c, .cpp, .go
    case frontend   // .tsx, .jsx, .vue, .css
    case backend    // .php, .rb, .erb
    case scripting  // .py, .sh, .lua
    case data       // .sql, .ipynb
    case jvm        // .java, .kt, .scala
    case devops     // .yaml, .tf, .dockerfile
    case mobile     // .swift, .dart
    case polyglot   // no category >30%

    // Aliases for Schema compatibility
    case functional
    case creative
    case research

    /// The tint color for this specialty.
    var tintColor: SKColor {
        switch self {
        case .systems:
            // Warm industrial — ember tones
            return PushlingPalette.ember
        case .frontend:
            // Neon accents — tide/cyan
            return PushlingPalette.tide
        case .backend:
            // Warm stone — between ember and bone
            return PushlingPalette.lerp(
                from: PushlingPalette.ember,
                to: PushlingPalette.bone,
                t: 0.5
            )
        case .scripting:
            // Organic green — moss
            return PushlingPalette.moss
        case .data:
            // Matrix cyan — tide
            return PushlingPalette.tide
        case .jvm:
            // Structured blue — between tide and dusk
            return PushlingPalette.lerp(
                from: PushlingPalette.tide,
                to: PushlingPalette.dusk,
                t: 0.4
            )
        case .devops:
            // Ghost white — bone with low alpha
            return PushlingPalette.bone
        case .mobile:
            // Sleek — between tide and ember
            return PushlingPalette.lerp(
                from: PushlingPalette.tide,
                to: PushlingPalette.ember,
                t: 0.3
            )
        case .functional:
            // Elegant purple
            return PushlingPalette.dusk
        case .creative:
            // Warm gilt
            return PushlingPalette.gilt
        case .research:
            // Analytical — data-like
            return PushlingPalette.tide
        case .polyglot:
            // Starts neutral, will cycle
            return PushlingPalette.bone
        }
    }

    /// The alpha intensity for this specialty's tint.
    var tintAlpha: CGFloat {
        switch self {
        case .frontend, .data:
            return 0.20  // Slightly more visible for neon/matrix feel
        default:
            return 0.15  // Subtle default
        }
    }
}

// MARK: - WorldTinting

/// Manages the diet-influenced world color tint overlay.
/// A single sprite covers the entire scene with a low-alpha color.
final class WorldTinting {

    // MARK: - Constants

    /// Duration of tint crossfade when specialty changes.
    static let crossfadeDuration: TimeInterval = 10.0

    /// Duration of polyglot color cycling.
    static let polyglotCycleDuration: TimeInterval = 30.0

    /// Z-position for the tint overlay (above world, below HUD/debug).
    static let tintZPosition: CGFloat = 500

    // MARK: - Properties

    /// The tint overlay node.
    private var overlayNode: SKSpriteNode?

    /// Current specialty driving the tint.
    private(set) var currentSpecialty: LanguageSpecialty = .polyglot

    /// Whether the polyglot cycling is active.
    private var isPolyglotCycling = false

    /// The scene this tinting is attached to.
    private weak var scene: SKScene?

    // MARK: - Setup

    /// Creates the tint overlay and adds it to the scene.
    /// - Parameter scene: The PushlingScene.
    func attach(to scene: SKScene) {
        self.scene = scene

        let overlay = SKSpriteNode(
            color: .clear,
            size: CGSize(
                width: ParallaxSystem.sceneWidth,
                height: ParallaxSystem.sceneHeight
            )
        )
        overlay.name = "worldTint"
        overlay.anchorPoint = CGPoint(x: 0, y: 0)
        overlay.position = .zero
        overlay.zPosition = Self.tintZPosition
        overlay.blendMode = .alpha
        overlay.alpha = 0

        scene.addChild(overlay)
        self.overlayNode = overlay
    }

    // MARK: - Tint Updates

    /// Sets the world tint based on the creature's language specialty.
    /// If the specialty changed, performs a 10-second crossfade.
    ///
    /// - Parameter specialtyString: The specialty string from SQLite
    ///   (e.g., "systems", "frontend", "polyglot").
    func updateSpecialty(_ specialtyString: String) {
        guard let specialty = LanguageSpecialty(rawValue: specialtyString) else {
            return
        }

        guard specialty != currentSpecialty else { return }

        let previousSpecialty = currentSpecialty
        currentSpecialty = specialty

        // Stop any existing polyglot cycling
        if isPolyglotCycling {
            overlayNode?.removeAction(forKey: "polyglotCycle")
            isPolyglotCycling = false
        }

        if specialty == .polyglot {
            startPolyglotCycle()
        } else {
            crossfade(
                from: previousSpecialty.tintColor,
                fromAlpha: previousSpecialty.tintAlpha,
                to: specialty.tintColor,
                toAlpha: specialty.tintAlpha
            )
        }
    }

    /// Immediately applies a tint without crossfade (used on launch).
    func applyImmediate(_ specialtyString: String) {
        guard let specialty = LanguageSpecialty(rawValue: specialtyString) else {
            return
        }

        currentSpecialty = specialty

        if specialty == .polyglot {
            startPolyglotCycle()
        } else {
            overlayNode?.color = specialty.tintColor
            overlayNode?.alpha = specialty.tintAlpha
        }
    }

    // MARK: - Private: Crossfade

    /// Crossfades the tint overlay from one color/alpha to another.
    private func crossfade(from fromColor: SKColor,
                           fromAlpha: CGFloat,
                           to toColor: SKColor,
                           toAlpha: CGFloat) {
        guard let overlay = overlayNode else { return }

        overlay.removeAction(forKey: "crossfade")

        // Ensure current state is the "from" color
        overlay.color = fromColor
        overlay.alpha = fromAlpha

        let colorAction = SKAction.colorize(
            with: toColor,
            colorBlendFactor: 1.0,
            duration: Self.crossfadeDuration
        )
        let alphaAction = SKAction.fadeAlpha(
            to: toAlpha,
            duration: Self.crossfadeDuration
        )
        colorAction.timingMode = .easeInEaseOut
        alphaAction.timingMode = .easeInEaseOut

        overlay.run(
            SKAction.group([colorAction, alphaAction]),
            withKey: "crossfade"
        )
    }

    // MARK: - Private: Polyglot Cycling

    /// Starts the polyglot color cycling — shifts between specialty
    /// tints over a 30-second cycle.
    private func startPolyglotCycle() {
        guard let overlay = overlayNode else { return }
        isPolyglotCycling = true

        let specialties: [LanguageSpecialty] = [
            .systems, .frontend, .backend, .scripting, .data, .jvm
        ]
        let segmentDuration = Self.polyglotCycleDuration
            / TimeInterval(specialties.count)

        var actions: [SKAction] = []
        for specialty in specialties {
            let colorize = SKAction.colorize(
                with: specialty.tintColor,
                colorBlendFactor: 1.0,
                duration: segmentDuration
            )
            colorize.timingMode = .easeInEaseOut
            actions.append(colorize)
        }

        overlay.alpha = 0.15
        overlay.run(
            SKAction.repeatForever(SKAction.sequence(actions)),
            withKey: "polyglotCycle"
        )
    }
}
