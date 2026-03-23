// EmotionalVisualController.swift — Maps emotional state to creature visuals
//
// Bridges the EmotionalState system (4 axes, updated per-frame) to the
// creature's body part controllers (tail, ears, eyes, breathing).
// Uses hysteresis to prevent flickering at thresholds.

import SpriteKit

final class EmotionalVisualController {

    private weak var creature: CreatureNode?
    private weak var emotionalState: EmotionalState?

    // Hysteresis: track which visual state is active to avoid flickering.
    // Only transition when axis crosses threshold by 5+ points.
    private var isSadActive = false
    private var isCuriousActive = false
    private var isEnergeticActive = false
    private var isTiredActive = false
    private var isContentActive = false
    private var isHangryActive = false

    private static let activateMargin: Double = 5.0

    init(creature: CreatureNode, emotionalState: EmotionalState) {
        self.creature = creature
        self.emotionalState = emotionalState
    }

    /// Called each frame from PushlingScene.updateRender().
    func update() {
        guard let creature = creature,
              let emo = emotionalState else { return }

        let sat = emo.satisfaction
        let cur = emo.curiosity
        let eng = emo.energy
        let con = emo.contentment

        // Hangry: low satisfaction + some energy (priority state)
        let hangryTarget = sat < 25 && eng > 40
        if hangryTarget != isHangryActive {
            if hangryTarget && sat < 25 - Self.activateMargin || !hangryTarget && sat > 30 {
                isHangryActive = hangryTarget
                if isHangryActive {
                    creature.earLeftController?.setState("back", duration: 0.5)
                    creature.earRightController?.setState("back", duration: 0.5)
                    creature.tailController?.setState("twitch_tip", duration: 0.5)
                }
            }
        }

        // Skip other ear/tail states if hangry is active
        guard !isHangryActive else {
            updateBreathing(creature: creature, energy: eng)
            return
        }

        // Low satisfaction → sad (droopy tail, droopy ears)
        let sadTarget = sat < 30
        if sadTarget != isSadActive {
            let threshold = sadTarget ? 30.0 - Self.activateMargin : 35.0
            if (sadTarget && sat < threshold) || (!sadTarget && sat > threshold) {
                isSadActive = sadTarget
                creature.tailController?.setState(
                    isSadActive ? "low" : "sway", duration: 0.5)
                creature.earLeftController?.setState(
                    isSadActive ? "droop" : "neutral", duration: 0.5)
                creature.earRightController?.setState(
                    isSadActive ? "droop" : "neutral", duration: 0.5)
            }
        }

        // High curiosity → alert (perked ears, wide eyes)
        let curiousTarget = cur > 70
        if curiousTarget != isCuriousActive {
            let threshold = curiousTarget ? 70.0 + Self.activateMargin : 65.0
            if (curiousTarget && cur > threshold) || (!curiousTarget && cur < threshold) {
                isCuriousActive = curiousTarget
                if !isSadActive {
                    creature.earLeftController?.setState(
                        isCuriousActive ? "perk" : "neutral", duration: 0.5)
                    creature.earRightController?.setState(
                        isCuriousActive ? "perk" : "neutral", duration: 0.5)
                }
                creature.eyeLeftController?.setState(
                    isCuriousActive ? "wide" : "open", duration: 0.3)
                creature.eyeRightController?.setState(
                    isCuriousActive ? "wide" : "open", duration: 0.3)
            }
        }

        // High contentment → happy tail
        let contentTarget = con > 75
        if contentTarget != isContentActive {
            let threshold = contentTarget ? 75.0 + Self.activateMargin : 70.0
            if (contentTarget && con > threshold) || (!contentTarget && con < threshold) {
                isContentActive = contentTarget
                if !isSadActive {
                    creature.tailController?.setState(
                        isContentActive ? "sway" : "still", duration: 0.5)
                }
            }
        }

        // Low energy → sleepy eyes
        let tiredTarget = eng < 30
        if tiredTarget != isTiredActive {
            let threshold = tiredTarget ? 30.0 - Self.activateMargin : 35.0
            if (tiredTarget && eng < threshold) || (!tiredTarget && eng > threshold) {
                isTiredActive = tiredTarget
                if !isCuriousActive {
                    creature.eyeLeftController?.setState(
                        isTiredActive ? "half" : "open", duration: 0.5)
                    creature.eyeRightController?.setState(
                        isTiredActive ? "half" : "open", duration: 0.5)
                }
            }
        }

        updateBreathing(creature: creature, energy: eng)
    }

    /// Modulate breathing speed based on energy axis.
    private func updateBreathing(creature: CreatureNode, energy: Double) {
        if energy > 70 {
            creature.breathPeriodOverride = 2.0  // Faster when energetic
        } else if energy < 30 {
            creature.breathPeriodOverride = 3.5  // Slower when tired
        } else {
            creature.breathPeriodOverride = nil  // Default 2.5s
        }
    }
}
