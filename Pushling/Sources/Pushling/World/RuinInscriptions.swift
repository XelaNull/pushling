// RuinInscriptions.swift — Journal fragments displayed on terrain ruins
// P3-T3-11: Scattered ruin pillars can display ancient memories.
//
// When creature examines a ruin (30% chance), a journal fragment appears.
// Text: first 10 words of an old journal entry, in tiny Ash text at 60% alpha.
// Visible for 3 seconds. Creature tilts head while reading, looks thoughtful after.
// Available at Beast+ stage (creature needs literacy).
// Maximum 1 inscription reading per 30 minutes.
//
// Node budget: 1 node (the text label). Only active during an inscription reading.

import SpriteKit

// MARK: - Ruin Inscriptions System

/// Manages the display of journal fragment inscriptions on ruin pillars.
/// Queries the journal for old entries and displays them as tiny atmospheric text.
final class RuinInscriptionSystem {

    // MARK: - Constants

    /// Probability of an inscription appearing when examining a ruin.
    private static let inscriptionChance: Double = 0.30

    /// Duration the inscription text is visible (seconds).
    private static let displayDuration: TimeInterval = 3.0

    /// Fade in/out duration (seconds).
    private static let fadeDuration: TimeInterval = 0.5

    /// Cooldown between inscription readings (seconds).
    private static let cooldown: TimeInterval = 1800  // 30 minutes

    /// Maximum words to display from journal entry.
    private static let maxWords = 10

    /// Font size for inscription text.
    private static let fontSize: CGFloat = 5.0

    /// Text color and alpha.
    private static let textAlpha: CGFloat = 0.6

    // MARK: - Nodes

    /// The inscription text label.
    private let textNode: SKLabelNode

    // MARK: - State

    /// Whether the system is enabled (Beast+ stage).
    private(set) var isEnabled = false

    /// Cooldown timer until next inscription is allowed.
    private var cooldownTimer: TimeInterval = 0

    /// Whether an inscription is currently being displayed.
    private(set) var isDisplaying = false

    /// Cached journal fragments for display. Refreshed periodically.
    private var cachedFragments: [String] = []

    /// Index into cached fragments (cycles through).
    private var fragmentIndex = 0

    // MARK: - Callbacks

    /// Called when the creature should display "reading" behavior.
    /// Parameter: true when reading starts, false when reading ends.
    var onCreatureReading: ((Bool) -> Void)?

    // MARK: - Init

    init() {
        textNode = SKLabelNode(fontNamed: "Menlo")
        textNode.fontSize = Self.fontSize
        textNode.fontColor = PushlingPalette.withAlpha(PushlingPalette.ash,
                                                        alpha: Self.textAlpha)
        textNode.horizontalAlignmentMode = .center
        textNode.verticalAlignmentMode = .bottom
        textNode.alpha = 0
        textNode.name = "ruin_inscription"
        textNode.zPosition = 15  // Above terrain objects
    }

    // MARK: - Scene Integration

    /// Add the text node to the foreground layer.
    func addToLayer(_ foreLayer: SKNode) {
        foreLayer.addChild(textNode)
    }

    /// Remove from scene.
    func removeFromScene() {
        textNode.removeFromParent()
    }

    // MARK: - Configuration

    /// Update stage gate. Enables at Beast+.
    func configureForStage(_ stage: GrowthStage) {
        isEnabled = stage >= .beast
    }

    // MARK: - Journal Fragment Management

    /// Load journal fragments from the database.
    /// Call periodically (e.g., every 10 minutes) to refresh the cache.
    /// - Parameter fragments: Array of journal summary strings (oldest first).
    func loadFragments(_ fragments: [String]) {
        cachedFragments = fragments.compactMap { summary in
            let trimmed = truncateToWords(summary, maxWords: Self.maxWords)
            return trimmed.isEmpty ? nil : "\"\(trimmed)\""
        }
        fragmentIndex = 0

        NSLog("[Pushling/Ruins] Loaded %d inscription fragments",
              cachedFragments.count)
    }

    // MARK: - Ruin Examination

    /// Called when the creature examines a ruin pillar.
    /// Rolls the dice and potentially displays an inscription.
    /// - Parameters:
    ///   - ruinWorldX: World-X position of the ruin.
    ///   - ruinY: Y position of the ruin top (text appears above it).
    /// - Returns: True if an inscription was triggered.
    @discardableResult
    func onRuinExamined(ruinWorldX: CGFloat, ruinY: CGFloat) -> Bool {
        guard isEnabled else { return false }
        guard !isDisplaying else { return false }
        guard cooldownTimer <= 0 else { return false }
        guard !cachedFragments.isEmpty else { return false }

        // Roll for inscription
        guard Double.random(in: 0...1) < Self.inscriptionChance else {
            return false
        }

        // Select a fragment (prefer older entries)
        let fragment = cachedFragments[fragmentIndex % cachedFragments.count]
        fragmentIndex += 1

        // Display the inscription
        displayInscription(fragment, at: CGPoint(x: ruinWorldX,
                                                   y: ruinY + 2))

        return true
    }

    // MARK: - Display

    private func displayInscription(_ text: String, at position: CGPoint) {
        isDisplaying = true
        textNode.text = text
        textNode.position = position

        // Notify creature to show reading behavior
        onCreatureReading?(true)

        // Fade in, hold, fade out
        textNode.removeAllActions()
        textNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: Self.textAlpha, duration: Self.fadeDuration),
            SKAction.wait(forDuration: Self.displayDuration),
            SKAction.fadeAlpha(to: 0, duration: Self.fadeDuration),
            SKAction.run { [weak self] in
                self?.isDisplaying = false
                self?.cooldownTimer = Self.cooldown
                self?.onCreatureReading?(false)
            }
        ]), withKey: "inscription")

        NSLog("[Pushling/Ruins] Displaying inscription: %@", text)
    }

    // MARK: - Frame Update

    /// Per-frame update for cooldown timer.
    func update(deltaTime: TimeInterval) {
        if cooldownTimer > 0 {
            cooldownTimer -= deltaTime
        }
    }

    // MARK: - Helpers

    /// Truncate a string to the first N words.
    private func truncateToWords(_ text: String, maxWords: Int) -> String {
        let words = text.split(separator: " ")
        let truncated = words.prefix(maxWords).joined(separator: " ")
        if words.count > maxWords {
            return truncated + "..."
        }
        return truncated
    }

    // MARK: - Node Count

    var nodeCount: Int {
        return isDisplaying ? 1 : 0
    }
}
