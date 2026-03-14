// SurpriseVariants.swift — Cross-system surprise integration (P8-T1-10)
// Integrates Phase 7 creation systems as surprise modifiers.
// Taught behaviors, placed objects, preferences, and companions
// can modify or replace base surprise animations.

import Foundation

// MARK: - Surprise Variant System

final class SurpriseVariantSystem {

    // MARK: - Variant Check

    /// Check if any variant applies to the selected surprise.
    /// Returns the variant tag if one applies, nil for base animation.
    ///
    /// Variant selection: 80% variant, 20% base when a variant is available.
    func checkVariant(
        surpriseId: Int,
        context: SurpriseContext,
        taughtBehaviors: [String],
        signatureBehaviors: [String],
        activePreferences: [(subject: String, valence: Double)],
        companionType: String?
    ) -> String? {
        let variants = availableVariants(
            surpriseId: surpriseId,
            context: context,
            taughtBehaviors: taughtBehaviors,
            signatureBehaviors: signatureBehaviors,
            activePreferences: activePreferences,
            companionType: companionType
        )

        guard !variants.isEmpty else { return nil }

        // 80% chance to use variant, 20% base
        guard Double.random(in: 0...1) < 0.8 else { return nil }

        return variants.randomElement()
    }

    // MARK: - Available Variants

    /// Determines which variants are available for a surprise.
    private func availableVariants(
        surpriseId: Int,
        context: SurpriseContext,
        taughtBehaviors: [String],
        signatureBehaviors: [String],
        activePreferences: [(subject: String, valence: Double)],
        companionType: String?
    ) -> [String] {
        var variants: [String] = []

        switch surpriseId {

        // Chase (#2): mouse companion replaces temp NPC
        case 2:
            if companionType == "mouse" {
                variants.append("companion_chase")
            }

        // Puddle Discovery (#7): mirror object extends interaction
        case 7:
            if context.placedObjects.contains("mirror") {
                variants.append("mirror_reflection")
            }

        // Clone (#10): ghost cat companion replaces clone
        case 10:
            if companionType == "ghost_cat" {
                variants.append("ghost_cat_meeting")
            }

        // Zoomies (#27): rain preference makes rain zoomies
        case 27:
            if preferenceValue(for: "rain", in: activePreferences) > 0.8 &&
               context.weather == "rain" {
                variants.append("rain_zoomies")
            }

        // Chattering (#31): bird companion targeted
        case 31:
            if companionType == "bird" {
                variants.append("companion_chattering")
            }

        // Kneading (#32): bed/cushion objects enhance
        case 32:
            if context.placedObjects.contains("bed") ||
               context.placedObjects.contains("cushion") {
                variants.append("comfort_kneading")
            }
            if context.placedObjects.contains("music_box") {
                variants.append("music_kneading")
            }

        // Head in Box (#34): already requires cardboard_box
        // but campfire story variant if campfire present
        case 34:
            break

        default:
            break
        }

        // Universal: Signature taught behaviors as surprise variants
        // Any surprise can be replaced by a Signature-mastery behavior performance
        if !signatureBehaviors.isEmpty && Double.random(in: 0...1) < 0.05 {
            // 5% chance per surprise check that a Signature behavior fires instead
            if let sig = signatureBehaviors.randomElement() {
                variants.append("signature_\(sig)")
            }
        }

        // Campfire stories: any idle surprise can become campfire story
        if context.placedObjects.contains("campfire") &&
           Double.random(in: 0...1) < 0.1 {
            variants.append("campfire_story")
        }

        return variants
    }

    // MARK: - Preference Lookup

    private func preferenceValue(
        for subject: String,
        in preferences: [(subject: String, valence: Double)]
    ) -> Double {
        preferences.first { $0.subject == subject }?.valence ?? 0
    }
}
