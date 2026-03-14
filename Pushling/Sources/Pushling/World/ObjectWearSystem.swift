// ObjectWearSystem.swift — Wear/repair lifecycle for world objects
// Each interaction increments wear (0.0 to 1.0).
// Visual wear stages: pristine -> worn -> weathered -> battered.
// Wear does NOT destroy objects (caps at 1.0).
// Claude repairs via pushling_world("modify", {repair: true}).
// Repair adds a "patched" visual mark.

import Foundation

// MARK: - Wear Stage

/// Visual wear stages for objects.
enum WearStage: String, Comparable {
    case pristine     // 0.0-0.3
    case worn         // 0.3-0.6
    case weathered    // 0.6-0.8
    case battered     // 0.8-1.0

    static func < (lhs: WearStage, rhs: WearStage) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .pristine:  return 0
        case .worn:      return 1
        case .weathered: return 2
        case .battered:  return 3
        }
    }

    init(wear: Double) {
        switch wear {
        case ..<0.3:  self = .pristine
        case ..<0.6:  self = .worn
        case ..<0.8:  self = .weathered
        default:      self = .battered
        }
    }

    /// Visual properties for this wear stage.
    var visualProperties: WearVisualProperties {
        switch self {
        case .pristine:
            return WearVisualProperties(
                alphaMultiplier: 1.0, desaturation: 0.0,
                positionJitter: 0.0, hasCracks: false, hasWobble: false
            )
        case .worn:
            return WearVisualProperties(
                alphaMultiplier: 0.9, desaturation: 0.1,
                positionJitter: 0.0, hasCracks: false, hasWobble: false
            )
        case .weathered:
            return WearVisualProperties(
                alphaMultiplier: 0.75, desaturation: 0.25,
                positionJitter: 0.3, hasCracks: true, hasWobble: false
            )
        case .battered:
            return WearVisualProperties(
                alphaMultiplier: 0.6, desaturation: 0.4,
                positionJitter: 0.5, hasCracks: true, hasWobble: true
            )
        }
    }
}

/// Visual properties applied at each wear stage.
struct WearVisualProperties {
    let alphaMultiplier: CGFloat
    let desaturation: CGFloat
    let positionJitter: CGFloat
    let hasCracks: Bool
    let hasWobble: Bool
}

// MARK: - Object Wear Record

/// Tracks wear state for a single object.
struct ObjectWearRecord {
    let objectID: String
    var wear: Double          // 0.0 to 1.0
    var repairCount: Int
    var totalInteractions: Int
    var lastInteractionAt: Date?

    /// Current wear stage.
    var stage: WearStage { WearStage(wear: wear) }

    /// Whether previous stage was different (for journal logging).
    func didCrossThreshold(previousWear: Double) -> Bool {
        WearStage(wear: previousWear) != WearStage(wear: wear)
    }
}

// MARK: - ObjectWearSystem

/// Manages wear/repair for all world objects.
final class ObjectWearSystem {

    // MARK: - Default Wear Rates

    /// Wear rate per interaction by interaction type.
    private static let wearRates: [String: Double] = [
        "batting_toy": 0.03,    // Toys wear faster
        "chasing":     0.02,
        "carrying":    0.02,
        "string_play": 0.04,    // String play is rough
        "pushing":     0.02,
        "sitting":     0.01,    // Furniture wears slowly
        "climbing":    0.015,
        "scratching":  0.025,   // Scratching wears moderately
        "hiding":      0.005,   // Hiding barely wears
        "examining":   0.005,   // Looking doesn't wear
        "rubbing":     0.01,
        "listening":   0.003,
        "watching":    0.001,   // Watching doesn't wear
        "reflecting":  0.005,
        "eating":      1.0,     // Consumables are consumed fully
    ]

    // MARK: - State

    /// Wear records keyed by object ID.
    private var records: [String: ObjectWearRecord] = [:]

    /// Callback when an object crosses a wear threshold.
    var onWearThresholdCrossed: ((String, WearStage) -> Void)?

    // MARK: - Wear Application

    /// Applies wear from an interaction.
    /// Returns the new wear stage if a threshold was crossed.
    @discardableResult
    func applyInteractionWear(
        objectID: String,
        interactionType: String,
        customRate: Double? = nil
    ) -> WearStage? {
        var record = records[objectID] ?? ObjectWearRecord(
            objectID: objectID, wear: 0.0,
            repairCount: 0, totalInteractions: 0,
            lastInteractionAt: nil
        )

        let previousWear = record.wear
        let rate = customRate ?? Self.wearRates[interactionType] ?? 0.01
        record.wear = Swift.min(record.wear + rate, 1.0)
        record.totalInteractions += 1
        record.lastInteractionAt = Date()
        records[objectID] = record

        // Check for threshold crossing
        if record.didCrossThreshold(previousWear: previousWear) {
            let newStage = record.stage
            onWearThresholdCrossed?(objectID, newStage)
            NSLog("[Pushling/Wear] Object '%@' reached %@ (wear: %.2f)",
                  objectID, newStage.rawValue, record.wear)
            return newStage
        }

        return nil
    }

    // MARK: - Repair

    /// Repairs an object, resetting wear to 0.0.
    /// Returns the repair count (for "patched" visual).
    @discardableResult
    func repair(objectID: String) -> Int {
        var record = records[objectID] ?? ObjectWearRecord(
            objectID: objectID, wear: 0.0,
            repairCount: 0, totalInteractions: 0,
            lastInteractionAt: nil
        )

        record.wear = 0.0
        record.repairCount += 1
        records[objectID] = record

        NSLog("[Pushling/Wear] Repaired '%@' (total repairs: %d)",
              objectID, record.repairCount)

        return record.repairCount
    }

    // MARK: - Queries

    /// Returns the current wear record for an object.
    func wearRecord(for objectID: String) -> ObjectWearRecord? {
        return records[objectID]
    }

    /// Returns the current wear stage for an object.
    func wearStage(for objectID: String) -> WearStage {
        return records[objectID]?.stage ?? .pristine
    }

    /// Returns the wear value (0.0-1.0) for an object.
    func wearValue(for objectID: String) -> Double {
        return records[objectID]?.wear ?? 0.0
    }

    /// Returns whether creature should interact less enthusiastically
    /// (adjusts behavior at high wear).
    func shouldReduceEnthusiasm(for objectID: String) -> Bool {
        let stage = wearStage(for: objectID)
        return stage >= .weathered
    }

    /// Returns the interaction weight modifier based on wear.
    /// Used by AttractionScorer to reduce attraction to worn objects.
    func wearAttractionModifier(for objectID: String) -> Double {
        let stage = wearStage(for: objectID)
        switch stage {
        case .pristine:  return 1.0
        case .worn:      return 0.9
        case .weathered: return 0.7
        case .battered:  return 0.5
        }
    }

    // MARK: - Bulk Operations

    /// Loads wear records from SQLite data.
    func loadRecords(_ data: [(id: String, wear: Double,
                                repairs: Int, interactions: Int)]) {
        records.removeAll()
        for entry in data {
            records[entry.id] = ObjectWearRecord(
                objectID: entry.id,
                wear: entry.wear,
                repairCount: entry.repairs,
                totalInteractions: entry.interactions,
                lastInteractionAt: nil
            )
        }
    }

    /// Removes tracking for a removed object.
    func removeObject(id: String) {
        records.removeValue(forKey: id)
    }

    /// Resets all wear state.
    func reset() {
        records.removeAll()
    }

    /// All objects currently at or above a given wear stage.
    func objectsAtOrAbove(_ stage: WearStage) -> [ObjectWearRecord] {
        return records.values.filter { $0.stage >= stage }
    }
}
