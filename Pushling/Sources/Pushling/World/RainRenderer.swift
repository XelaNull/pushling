// RainRenderer.swift — Rain particle system with terrain impact splashes
// P3-T2-05: Individual 1x2pt droplets falling at 100-140pts/sec.
// 30-50 active droplets covering the viewport. Slight horizontal wind drift.
// Splash on terrain impact: 3 particles, 1x1pt, spread outward over 100ms.
//
// Uses a manual particle pool (recycled SKSpriteNode instances) for
// terrain-aware splash placement. No per-frame allocations.

import SpriteKit

// MARK: - Rain Droplet

/// A reusable rain droplet with position, velocity, and active state.
private struct RainDroplet {
    var positionX: CGFloat = 0
    var positionY: CGFloat = 0
    var velocityY: CGFloat = 0    // Fall speed (negative, pts/sec)
    var velocityX: CGFloat = 0    // Wind drift (pts/sec)
    var isActive: Bool = false

    /// Reset for reuse.
    mutating func spawn(sceneWidth: CGFloat, sceneHeight: CGFloat, windDrift: CGFloat) {
        positionX = CGFloat.random(in: 0...sceneWidth)
        positionY = sceneHeight + CGFloat.random(in: 0...5)  // Start just above top
        velocityY = -CGFloat.random(in: 100...140)           // 100-140 pts/sec downward
        velocityX = windDrift + CGFloat.random(in: -3...3)   // Wind + jitter
        isActive = true
    }
}

// MARK: - Splash Particle

/// A small splash particle that expands outward from impact point.
private struct SplashParticle {
    var positionX: CGFloat = 0
    var positionY: CGFloat = 0
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0
    var lifetime: CGFloat = 0     // Remaining life (seconds)
    var isActive: Bool = false

    /// Spawn at impact point with outward velocity.
    mutating func spawn(x: CGFloat, y: CGFloat, angle: CGFloat) {
        positionX = x
        positionY = y
        let speed: CGFloat = CGFloat.random(in: 15...30)
        velocityX = cos(angle) * speed
        velocityY = sin(angle) * speed
        lifetime = 0.1   // 100ms
        isActive = true
    }
}

// MARK: - Rain Renderer

/// Manages rain droplets and splash particles as a recycled particle pool.
/// All sprites are pre-allocated and reused. No allocations during gameplay.
final class RainRenderer {

    // MARK: - Constants

    /// Maximum concurrent droplets (pool size).
    private static let maxDroplets = 50

    /// Maximum concurrent splash particles.
    private static let maxSplashes = 30

    /// Droplet visual size.
    private static let dropletSize = CGSize(width: 1, height: 2)

    /// Splash visual size.
    private static let splashSize = CGSize(width: 1, height: 1)

    /// Ground Y position (terrain baseline). Adjusted when terrain provides real height.
    private static let groundY: CGFloat = 4.0

    /// Splash particles per droplet impact.
    private static let splashesPerImpact = 3

    /// Spawn rate: droplets per second at full intensity.
    private static let spawnRate: Double = 60  // Maintains 30-50 active

    /// Wind drift speed range (pts/sec).
    private static let windDriftRange: ClosedRange<CGFloat> = 5...15

    /// Scene dimensions.
    private static let sceneWidth: CGFloat = 1085
    private static let sceneHeight: CGFloat = 30

    // MARK: - Node Containers

    /// Container node for all rain elements.
    private let containerNode = SKNode()

    // MARK: - Particle Pools

    /// Pre-allocated droplet sprites.
    private var dropletSprites: [SKSpriteNode] = []

    /// Droplet data (parallel array with sprites).
    private var droplets: [RainDroplet] = []

    /// Pre-allocated splash sprites.
    private var splashSprites: [SKSpriteNode] = []

    /// Splash data (parallel array with sprites).
    private var splashes: [SplashParticle] = []

    // MARK: - State

    /// Intensity multiplier (0.0 = off, 1.0 = full rain). Set by WeatherSystem.
    var intensity: CGFloat = 0 {
        didSet { containerNode.alpha = intensity }
    }

    /// Whether the renderer is actively spawning new droplets.
    private var isActive = false

    /// Current wind drift direction.
    private var windDrift: CGFloat = 10

    /// Spawn accumulator (fractional droplets to spawn).
    private var spawnAccumulator: Double = 0

    /// Terrain height query callback. Set by the scene to provide real terrain heights.
    /// Takes an X position, returns the Y height of the terrain at that point.
    var terrainHeightAt: ((CGFloat) -> CGFloat)?

    // MARK: - Shared Textures

    private let dropletTexture: SKTexture
    private let splashTexture: SKTexture

    // MARK: - Init

    init() {
        // Create Tide-colored droplet texture
        dropletTexture = Self.createTexture(
            size: Self.dropletSize,
            r: 0x00, g: 0xD4, b: 0xFF, a: 153  // Tide at alpha 0.6
        )

        // Create Tide-colored splash texture
        splashTexture = Self.createTexture(
            size: Self.splashSize,
            r: 0x00, g: 0xD4, b: 0xFF, a: 77   // Tide at alpha 0.3
        )

        // Pre-allocate droplet pool
        for _ in 0..<Self.maxDroplets {
            let sprite = SKSpriteNode(texture: dropletTexture, size: Self.dropletSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.isHidden = true
            containerNode.addChild(sprite)
            dropletSprites.append(sprite)
            droplets.append(RainDroplet())
        }

        // Pre-allocate splash pool
        for _ in 0..<Self.maxSplashes {
            let sprite = SKSpriteNode(texture: splashTexture, size: Self.splashSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.isHidden = true
            containerNode.addChild(sprite)
            splashSprites.append(sprite)
            splashes.append(SplashParticle())
        }

        containerNode.zPosition = 50  // Above terrain, below HUD
        containerNode.alpha = 0
        windDrift = CGFloat.random(in: Self.windDriftRange) * (Bool.random() ? 1 : -1)
    }

    // MARK: - Texture Creation

    private static func createTexture(size: CGSize, r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> SKTexture {
        let w = Int(size.width)
        let h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            pixels[i * 4] = r
            pixels[i * 4 + 1] = g
            pixels[i * 4 + 2] = b
            pixels[i * 4 + 3] = a
        }
        let texture = SKTexture(data: Data(pixels), size: size)
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
        // Randomize wind direction on each rain event
        windDrift = CGFloat.random(in: Self.windDriftRange) * (Bool.random() ? 1 : -1)
    }

    func deactivate() {
        isActive = false
        // Existing droplets will naturally fall and deactivate
    }

    // MARK: - Frame Update

    /// Update all droplets and splashes. Called every frame during rain/storm.
    func update(deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)

        // Spawn new droplets
        if isActive && intensity > 0.1 {
            spawnDroplets(deltaTime: deltaTime)
        }

        // Update droplets
        updateDroplets(dt: dt)

        // Update splashes
        updateSplashes(dt: dt)
    }

    // MARK: - Droplet Management

    /// Spawn droplets based on spawn rate and delta time.
    private func spawnDroplets(deltaTime: TimeInterval) {
        spawnAccumulator += Self.spawnRate * stormSpawnRateMultiplier * deltaTime * Double(intensity)

        while spawnAccumulator >= 1.0 {
            spawnAccumulator -= 1.0
            spawnOneDroplet()
        }
    }

    /// Find an inactive droplet and spawn it.
    private func spawnOneDroplet() {
        for i in 0..<droplets.count {
            if !droplets[i].isActive {
                droplets[i].spawn(
                    sceneWidth: Self.sceneWidth,
                    sceneHeight: Self.sceneHeight,
                    windDrift: windDrift
                )
                dropletSprites[i].isHidden = false
                dropletSprites[i].position = CGPoint(
                    x: droplets[i].positionX,
                    y: droplets[i].positionY
                )
                return
            }
        }
        // All droplets in use — skip this spawn (natural rate limiting)
    }

    /// Update all active droplets.
    private func updateDroplets(dt: CGFloat) {
        for i in 0..<droplets.count {
            guard droplets[i].isActive else {
                dropletSprites[i].isHidden = true
                continue
            }

            // Move droplet
            droplets[i].positionX += droplets[i].velocityX * dt
            droplets[i].positionY += droplets[i].velocityY * dt

            // Get terrain height at this X position
            let groundY = terrainHeightAt?(droplets[i].positionX) ?? Self.groundY

            // Check for terrain impact
            if droplets[i].positionY <= groundY {
                // Spawn splash particles at impact
                spawnSplash(x: droplets[i].positionX, y: groundY)

                // Deactivate droplet
                droplets[i].isActive = false
                dropletSprites[i].isHidden = true
                continue
            }

            // Check for off-screen (horizontal drift)
            if droplets[i].positionX < -5 || droplets[i].positionX > Self.sceneWidth + 5 {
                droplets[i].isActive = false
                dropletSprites[i].isHidden = true
                continue
            }

            // Update sprite position
            dropletSprites[i].position = CGPoint(
                x: droplets[i].positionX,
                y: droplets[i].positionY
            )
        }
    }

    // MARK: - Splash Management

    /// Spawn splash particles at an impact point.
    private func spawnSplash(x: CGFloat, y: CGFloat) {
        var spawned = 0
        let angles: [CGFloat] = [
            CGFloat.random(in: 0.3...1.2),     // Upper-right
            CGFloat.random(in: 1.9...2.8),      // Upper-left
            CGFloat.random(in: 0.8...2.3)       // Center-up
        ]

        for i in 0..<splashes.count {
            guard !splashes[i].isActive && spawned < Self.splashesPerImpact else {
                if spawned >= Self.splashesPerImpact { return }
                continue
            }

            splashes[i].spawn(x: x, y: y, angle: angles[spawned])
            splashSprites[i].isHidden = false
            splashSprites[i].position = CGPoint(x: x, y: y)
            spawned += 1
        }
    }

    /// Update all active splash particles.
    private func updateSplashes(dt: CGFloat) {
        for i in 0..<splashes.count {
            guard splashes[i].isActive else {
                splashSprites[i].isHidden = true
                continue
            }

            splashes[i].lifetime -= dt
            if splashes[i].lifetime <= 0 {
                splashes[i].isActive = false
                splashSprites[i].isHidden = true
                continue
            }

            // Move splash outward
            splashes[i].positionX += splashes[i].velocityX * dt
            splashes[i].positionY += splashes[i].velocityY * dt

            // Gravity on splashes
            splashes[i].velocityY -= 80 * dt

            // Update sprite
            splashSprites[i].position = CGPoint(
                x: splashes[i].positionX,
                y: splashes[i].positionY
            )

            // Fade out over lifetime
            splashSprites[i].alpha = max(0, splashes[i].lifetime / 0.1)
        }
    }

    // MARK: - Storm Support

    /// Increase droplet density for storm conditions (60-80 active).
    /// Called by StormSystem to override normal spawn rate.
    var stormSpawnRateMultiplier: Double = 1.0

    /// Active droplet count (for debug/monitoring).
    var activeDropletCount: Int {
        return droplets.filter(\.isActive).count
    }
}
