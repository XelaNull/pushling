// WorldManager+FogOfWar.swift — Fog of war integration methods
// Extracted from WorldManager to respect the 500-line file limit.
// Provides per-frame fog updates and stage transition animation wiring.

import CoreGraphics
import Foundation

extension WorldManager {

    // MARK: - Fog of War Stage Transition

    /// Update the fog of war configuration for a stage transition.
    /// - Parameters:
    ///   - oldConfig: The previous fog configuration (for animation start).
    ///   - newConfig: The new fog configuration (animation target).
    ///   - animated: Whether to animate the fog retreat (true for evolution).
    func updateFogStage(from oldConfig: FogOfWarConfig,
                        to newConfig: FogOfWarConfig,
                        animated: Bool) {
        guard let fog = fogOfWar else { return }

        if animated {
            fog.onEvolutionReveal(
                from: oldConfig, to: newConfig,
                duration: 1.8  // Slightly longer than typical evolution flash
            )
        } else {
            fog.updateConfig(newConfig, animated: false)
        }
    }

    // MARK: - Fog of War Per-Frame Update

    /// Update fog of war each frame with creature position data.
    /// Called from the scene's update loop after camera and world updates.
    ///
    /// - Parameters:
    ///   - creatureScreenX: Creature's screen-space X (scene coordinates).
    ///   - creatureWorldX: Creature's world-space X.
    ///   - zoom: Current camera zoom level.
    ///   - deltaTime: Time since last frame.
    func updateFogOfWar(creatureScreenX: CGFloat,
                         creatureWorldX: CGFloat,
                         zoom: CGFloat,
                         deltaTime: TimeInterval) {
        guard let fog = fogOfWar else { return }
        fog.setZoomLevel(zoom)
        fog.update(
            creatureScreenX: creatureScreenX,
            creatureWorldX: creatureWorldX,
            deltaTime: deltaTime
        )
    }
}
