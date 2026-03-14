// SnowRenderer.swift — Gentle snowfall with accumulation
// P3-T2-06: 1x1pt Bone-colored flakes drifting at 20-40pts/sec.
// Horizontal drift: ±10pts/sec sine-wave lateral movement.
// 15-30 active flakes. Accumulation builds 1pt on terrain over time.
//
// Uses a manual particle pool with recycled SKSpriteNode instances.
// Accumulation tracked as a float (0.0-1.0), rendered as a terrain cap.

import SpriteKit

// MARK: - Snowflake

/// A reusable snowflake with position, velocity, and oscillation state.
private struct Snowflake {
    var positionX: CGFloat = 0
    var positionY: CGFloat = 0
    var velocityY: CGFloat = 0        // Fall speed (negative, pts/sec)
    var lateralPhase: CGFloat = 0     // Sine-wave phase for horizontal drift
    var lateralFrequency: CGFloat = 0 // Hz of lateral oscillation
    var lateralAmplitude: CGFloat = 0 // Max horizontal drift (pts/sec)
    var baseAlpha: CGFloat = 0.5      // Individual flake alpha
    var isActive: Bool = false

    /// Reset for reuse.
    mutating func spawn(sceneWidth: CGFloat, sceneHeight: CGFloat) {
        positionX = CGFloat.random(in: 0...sceneWidth)
        positionY = sceneHeight + CGFloat.random(in: 0...8)  // Start above top
        velocityY = -CGFloat.random(in: 20...40)             // 20-40 pts/sec
        lateralPhase = CGFloat.random(in: 0...(2 * .pi))
        lateralFrequency = CGFloat.random(in: 0.3...0.8)     // Gentle oscillation
        lateralAmplitude = CGFloat.random(in: 5...10)         // ±10pts/sec max
        baseAlpha = CGFloat.random(in: 0.5...0.8)
        isActive = true
    }
}

// MARK: - Snow Renderer

/// Manages snowflake particles and terrain accumulation.
/// Pool of 30 pre-allocated sprites, recycled continuously.
final class SnowRenderer {

    // MARK: - Constants

    /// Maximum concurrent snowflakes (pool size).
    private static let maxFlakes = 30

    /// Snowflake visual size.
    private static let flakeSize = CGSize(width: 1, height: 1)

    /// Ground Y position (terrain baseline).
    private static let groundY: CGFloat = 4.0

    /// Spawn rate: flakes per second at full intensity.
    private static let spawnRate: Double = 12  // Maintains 15-30 active at slow fall speed

    /// Scene dimensions.
    private static let sceneWidth: CGFloat = 1085
    private static let sceneHeight: CGFloat = 30

    /// Accumulation rate: fraction per minute during active snow.
    private static let accumulationRate: CGFloat = 0.05  // 0.05/min

    /// Melt rate: fraction per minute after snow stops.
    private static let meltRate: CGFloat = 0.2  // 0.2/min — melts in ~5 min

    /// Maximum accumulation height in points.
    private static let maxAccumulationHeight: CGFloat = 1.0

    // MARK: - Node Containers

    /// Container node for all snow elements.
    private let containerNode = SKNode()

    /// Accumulation overlay node (thin white line on terrain).
    private let accumulationNode: SKShapeNode

    // MARK: - Particle Pool

    /// Pre-allocated flake sprites.
    private var flakeSprites: [SKSpriteNode] = []

    /// Flake data (parallel array with sprites).
    private var flakes: [Snowflake] = []

    // MARK: - State

    /// Intensity multiplier (0.0 = off, 1.0 = full snow). Set by WeatherSystem.
    var intensity: CGFloat = 0 {
        didSet { containerNode.alpha = max(intensity, accumulationLevel > 0.01 ? 1.0 : 0) }
    }

    /// Whether the renderer is actively spawning new flakes.
    private var isActive = false

    /// Spawn accumulator (fractional flakes to spawn).
    private var spawnAccumulator: Double = 0

    /// Current accumulation level (0.0-1.0).
    private(set) var accumulationLevel: CGFloat = 0

    /// Terrain height query callback.
    var terrainHeightAt: ((CGFloat) -> CGFloat)?

    // MARK: - Shared Texture

    private let flakeTexture: SKTexture

    // MARK: - Init

    init() {
        // Create Bone-colored flake texture
        flakeTexture = Self.createFlakeTexture()

        // Create accumulation bar (initially hidden)
        accumulationNode = SKShapeNode(
            rect: CGRect(x: 0, y: 0, width: Self.sceneWidth, height: Self.maxAccumulationHeight)
        )
        accumulationNode.fillColor = PushlingPalette.bone.withAlphaComponent(0.3)
        accumulationNode.strokeColor = .clear
        accumulationNode.position = CGPoint(x: 0, y: Self.groundY)
        accumulationNode.zPosition = 5  // Just above terrain
        accumulationNode.alpha = 0

        // Pre-allocate flake pool
        for _ in 0..<Self.maxFlakes {
            let sprite = SKSpriteNode(texture: flakeTexture, size: Self.flakeSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.isHidden = true
            containerNode.addChild(sprite)
            flakeSprites.append(sprite)
            flakes.append(Snowflake())
        }

        containerNode.addChild(accumulationNode)
        containerNode.zPosition = 50  // Same layer as rain
        containerNode.alpha = 0
    }

    // MARK: - Texture Creation

    private static func createFlakeTexture() -> SKTexture {
        // Bone at full alpha — individual sprite alpha controls visibility
        var pixels: [UInt8] = [0xF5, 0xF0, 0xE8, 0xFF]
        let texture = SKTexture(data: Data(pixels), size: CGSize(width: 1, height: 1))
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Scene Integration

    func addToScene(parent: SKNode) {
        parent.addChild(containerNode)
    }

    // MARK: - Activation

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
        // Existing flakes drift down naturally
    }

    // MARK: - Frame Update

    /// Update all snowflakes and accumulation. Called every frame during snow.
    func update(deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)

        // Spawn new flakes
        if isActive && intensity > 0.1 {
            spawnFlakes(deltaTime: deltaTime)
            updateAccumulation(dt: dt, isSnowing: true)
        } else if accumulationLevel > 0 {
            updateAccumulation(dt: dt, isSnowing: false)
        }

        // Update flakes
        updateFlakes(dt: dt)

        // Update accumulation visual
        updateAccumulationVisual()
    }

    // MARK: - Flake Management

    /// Spawn flakes based on spawn rate and delta time.
    private func spawnFlakes(deltaTime: TimeInterval) {
        spawnAccumulator += Self.spawnRate * deltaTime * Double(intensity)

        while spawnAccumulator >= 1.0 {
            spawnAccumulator -= 1.0
            spawnOneFlake()
        }
    }

    /// Find an inactive flake and spawn it.
    private func spawnOneFlake() {
        for i in 0..<flakes.count {
            if !flakes[i].isActive {
                flakes[i].spawn(sceneWidth: Self.sceneWidth, sceneHeight: Self.sceneHeight)
                flakeSprites[i].isHidden = false
                flakeSprites[i].alpha = flakes[i].baseAlpha
                flakeSprites[i].position = CGPoint(
                    x: flakes[i].positionX,
                    y: flakes[i].positionY
                )
                return
            }
        }
    }

    /// Update all active flakes.
    private func updateFlakes(dt: CGFloat) {
        for i in 0..<flakes.count {
            guard flakes[i].isActive else {
                flakeSprites[i].isHidden = true
                continue
            }

            // Vertical fall
            flakes[i].positionY += flakes[i].velocityY * dt

            // Lateral sine-wave drift
            flakes[i].lateralPhase += flakes[i].lateralFrequency * 2.0 * .pi * dt
            if flakes[i].lateralPhase > 100.0 * .pi {
                flakes[i].lateralPhase -= 100.0 * .pi
            }
            let lateralOffset = sin(flakes[i].lateralPhase) * flakes[i].lateralAmplitude * dt
            flakes[i].positionX += lateralOffset

            // Get terrain height
            let groundY = terrainHeightAt?(flakes[i].positionX) ?? Self.groundY

            // Check for terrain landing
            if flakes[i].positionY <= groundY {
                flakes[i].isActive = false
                flakeSprites[i].isHidden = true
                continue
            }

            // Check horizontal bounds
            if flakes[i].positionX < -10 || flakes[i].positionX > Self.sceneWidth + 10 {
                flakes[i].isActive = false
                flakeSprites[i].isHidden = true
                continue
            }

            // Update sprite
            flakeSprites[i].position = CGPoint(
                x: flakes[i].positionX,
                y: flakes[i].positionY
            )
        }
    }

    // MARK: - Accumulation

    /// Update snow accumulation level.
    private func updateAccumulation(dt: CGFloat, isSnowing: Bool) {
        if isSnowing {
            // Build up at accumulationRate per minute
            accumulationLevel = min(1.0, accumulationLevel + Self.accumulationRate * dt / 60.0)
        } else {
            // Melt at meltRate per minute
            accumulationLevel = max(0.0, accumulationLevel - Self.meltRate * dt / 60.0)
        }
    }

    /// Update the accumulation overlay visual.
    private func updateAccumulationVisual() {
        if accumulationLevel > 0.01 {
            accumulationNode.alpha = accumulationLevel * 0.5
            accumulationNode.yScale = accumulationLevel
        } else {
            accumulationNode.alpha = 0
        }
    }

    // MARK: - Query

    /// Active flake count (for debug/monitoring).
    var activeFlakeCount: Int {
        return flakes.filter(\.isActive).count
    }
}
