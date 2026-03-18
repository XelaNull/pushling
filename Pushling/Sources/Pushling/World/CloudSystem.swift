// CloudSystem.swift — Cloud rendering for the Touch Bar sky
// P3-T2-09: 6-8 clouds built from overlapping ellipses, drifting left
// with sine-wave vertical bob. Parallax scroll factor 0.25.
// Weather integration: wispy in clear, dense in cloudy, dark in storm, invisible in fog.
// Time-of-day tinting: Ember/Gilt at golden hour, Ash at night.
//
// Each cloud is 3-5 ellipses (SKShapeNode). Pool of 6-8 clouds = 24-40 child nodes.
// Clouds recycle (wrap around) when they scroll off the left edge.

import SpriteKit

// MARK: - Cloud Configuration

/// Per-cloud randomized parameters, assigned at spawn time.
private struct CloudConfig {
    let width: CGFloat         // Overall cloud width (30-80pt)
    let driftSpeed: CGFloat    // Horizontal speed (5-15pt/sec, leftward)
    let bobAmplitude: CGFloat  // Vertical sine amplitude (around 0.5pt)
    let bobPeriod: CGFloat     // Sine period in seconds (around 8s)
    let yBase: CGFloat         // Resting vertical center (16-27pt)
    let ellipseCount: Int      // Number of overlapping ellipses (3-5)
    var bobPhase: CGFloat      // Current sine phase (radians)
}

// MARK: - Cloud Node

/// A single cloud composed of overlapping ellipses.
/// All ellipses share the same parent SKNode for efficient repositioning.
private final class CloudNode: SKNode {

    /// The ellipse shapes composing this cloud.
    private var ellipses: [SKShapeNode] = []

    /// Current configuration (set on each recycle).
    fileprivate var config: CloudConfig

    /// Horizontal world-space position (used for parallax + wrapping).
    fileprivate var worldX: CGFloat = 0

    /// Current tint color applied to all ellipses.
    private var currentColor: SKColor = PushlingPalette.bone

    /// Current alpha applied to all ellipses.
    private var currentAlpha: CGFloat = 0.12

    fileprivate init(config: CloudConfig) {
        self.config = config
        super.init()
        buildEllipses()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// Rebuild ellipses for current config. Called on recycle.
    fileprivate func rebuild(with newConfig: CloudConfig) {
        config = newConfig
        for e in ellipses { e.removeFromParent() }
        ellipses.removeAll()
        buildEllipses()
    }

    /// Create the overlapping ellipses that form the cloud shape.
    private func buildEllipses() {
        let count = config.ellipseCount
        let baseW = config.width / CGFloat(count) * 1.4
        let baseH: CGFloat = 4.0  // Clouds are thin on the 30pt strip

        for i in 0..<count {
            // Vary each ellipse slightly for organic shape
            let fraction = CGFloat(i) / CGFloat(max(1, count - 1))
            let xOff = (fraction - 0.5) * config.width * 0.7
            let yOff = CGFloat.random(in: -1.0...1.0)
            let wScale = CGFloat.random(in: 0.7...1.3)
            let hScale = CGFloat.random(in: 0.6...1.2)

            let w = baseW * wScale
            let h = baseH * hScale
            let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            let path = CGPath(ellipseIn: rect, transform: nil)

            let shape = SKShapeNode(path: path)
            shape.strokeColor = .clear
            shape.fillColor = currentColor
            shape.alpha = currentAlpha
            shape.position = CGPoint(x: xOff, y: yOff)
            shape.zPosition = 0

            addChild(shape)
            ellipses.append(shape)
        }
    }

    /// Update tint color and alpha on all ellipses.
    fileprivate func applyAppearance(color: SKColor, alpha: CGFloat) {
        guard color != currentColor || abs(alpha - currentAlpha) > 0.001 else { return }
        currentColor = color
        currentAlpha = alpha
        for e in ellipses {
            e.fillColor = color
            e.alpha = alpha
        }
    }
}

// MARK: - Cloud System

/// Manages a pool of drifting clouds on the Touch Bar sky.
/// Clouds live on their own layer at zPosition -75 with parallax scroll factor 0.25.
/// Total node count: 24-40 (6-8 clouds x 3-5 ellipses each).
final class CloudSystem {

    // MARK: - Constants

    /// Scene dimensions (Touch Bar).
    private static let sceneWidth: CGFloat = 1085
    private static let sceneHeight: CGFloat = 30

    /// Cloud pool size.
    private static let minClouds = 6
    private static let maxClouds = 8

    /// Parallax scroll factor for the cloud layer.
    private static let scrollFactor: CGFloat = 0.25

    /// Layer z-position (between far layer and mid layer).
    private static let layerZ: CGFloat = -75

    /// Horizontal padding beyond viewport for recycling.
    private static let recyclePadding: CGFloat = 100

    /// Vertical placement range (upper portion of 30pt strip).
    private static let minY: CGFloat = 16
    private static let maxY: CGFloat = 27

    /// Speed range (pts/sec, leftward drift).
    private static let minSpeed: CGFloat = 5
    private static let maxSpeed: CGFloat = 15

    /// Cloud width range.
    private static let minWidth: CGFloat = 30
    private static let maxWidth: CGFloat = 80

    /// Vertical bob defaults.
    private static let bobAmplitude: CGFloat = 0.5
    private static let bobPeriod: CGFloat = 8.0

    // MARK: - Nodes

    /// Container node for all clouds.
    private let containerNode = SKNode()

    /// Pool of cloud nodes.
    private var clouds: [CloudNode] = []

    // MARK: - State

    /// Current weather state (affects cloud density and color).
    private var weatherState: WeatherState = .clear

    /// Current time period (affects tinting).
    private var timePeriod: TimePeriod = .day

    /// Cached appearance values to avoid recalculating every frame.
    private var cachedColor: SKColor = PushlingPalette.bone
    private var cachedAlpha: CGFloat = 0.12

    /// Total world-width used for cloud wrapping.
    /// Clouds wrap around a virtual strip wider than the viewport.
    private var wrapWidth: CGFloat {
        Self.sceneWidth / Self.scrollFactor + Self.recyclePadding * 2
    }

    // MARK: - Init

    init() {
        containerNode.zPosition = Self.layerZ
        containerNode.name = "cloud_layer"

        let count = Int.random(in: Self.minClouds...Self.maxClouds)
        for i in 0..<count {
            let config = randomConfig()
            let cloud = CloudNode(config: config)
            // Spread clouds evenly across the virtual wrap width, with jitter
            let spacing = wrapWidth / CGFloat(count)
            cloud.worldX = spacing * CGFloat(i) + CGFloat.random(in: -30...30)
            clouds.append(cloud)
            containerNode.addChild(cloud)
        }

        recalculateAppearance()
        applyAppearanceToAll()
    }

    // MARK: - Scene Integration

    /// Attach the cloud layer to a parent node (typically the scene root).
    func addToScene(parent: SKNode) {
        parent.addChild(containerNode)
    }

    // MARK: - Per-Frame Update

    /// Update cloud positions. Call once per frame.
    /// - Parameters:
    ///   - deltaTime: Frame delta in seconds.
    ///   - cameraWorldX: Current camera world-space X (for parallax).
    func update(deltaTime: TimeInterval, cameraWorldX: CGFloat) {
        let dt = CGFloat(deltaTime)

        // Parallax offset: clouds move slower than the camera
        let parallaxOffset = Self.sceneWidth / 2.0 - cameraWorldX * Self.scrollFactor

        for cloud in clouds {
            // Drift leftward
            cloud.worldX -= cloud.config.driftSpeed * dt

            // Vertical bob (sine wave)
            cloud.config.bobPhase += (2.0 * .pi / cloud.config.bobPeriod) * dt
            if cloud.config.bobPhase > 100.0 * .pi {
                cloud.config.bobPhase -= 100.0 * .pi
            }
            let bobY = cloud.config.bobAmplitude * sin(cloud.config.bobPhase)

            // Screen position = parallax offset + world position
            let screenX = parallaxOffset + cloud.worldX
            cloud.position = CGPoint(x: screenX, y: cloud.config.yBase + bobY)

            // Recycle: if cloud has drifted fully off the left edge
            if screenX < -cloud.config.width - Self.recyclePadding {
                recycleCloud(cloud, parallaxOffset: parallaxOffset)
            }
        }
    }

    // MARK: - Weather Integration

    /// Update cloud appearance for a new weather state.
    func updateWeather(_ state: WeatherState) {
        guard state != weatherState else { return }
        weatherState = state
        recalculateAppearance()
        applyAppearanceToAll()
    }

    // MARK: - Time-of-Day Integration

    /// Update cloud tinting for a new time period.
    func updateTimePeriod(_ period: TimePeriod) {
        guard period != timePeriod else { return }
        timePeriod = period
        recalculateAppearance()
        applyAppearanceToAll()
    }

    // MARK: - Appearance Calculation

    /// Recalculate the cached color and alpha based on weather + time.
    private func recalculateAppearance() {
        // Base color from time of day
        let baseColor: SKColor
        switch timePeriod {
        case .goldenHour:
            // Warm Ember/Gilt tint
            baseColor = PushlingPalette.lerp(from: PushlingPalette.ember, to: PushlingPalette.gilt, t: 0.5)
        case .dusk:
            baseColor = PushlingPalette.lerp(from: PushlingPalette.ember, to: PushlingPalette.bone, t: 0.4)
        case .dawn:
            baseColor = PushlingPalette.lerp(from: PushlingPalette.ember, to: PushlingPalette.bone, t: 0.6)
        case .deepNight, .lateNight:
            baseColor = PushlingPalette.ash
        case .evening:
            baseColor = PushlingPalette.lerp(from: PushlingPalette.ash, to: PushlingPalette.bone, t: 0.3)
        case .morning, .day:
            baseColor = PushlingPalette.bone
        }

        // Adjust color and alpha for weather
        switch weatherState {
        case .clear:
            // Wispy, faint clouds
            cachedColor = PushlingPalette.withAlpha(baseColor, alpha: 1.0)
            cachedAlpha = 0.12
        case .cloudy:
            // Dense, more opaque
            cachedColor = PushlingPalette.withAlpha(baseColor, alpha: 1.0)
            cachedAlpha = 0.35
        case .rain:
            // Darker, heavier
            cachedColor = PushlingPalette.lerp(from: baseColor, to: PushlingPalette.ash, t: 0.5)
            cachedAlpha = 0.40
        case .storm:
            // Dark Ash clouds
            cachedColor = PushlingPalette.lerp(from: PushlingPalette.ash, to: PushlingPalette.void_, t: 0.4)
            cachedAlpha = 0.55
        case .snow:
            // Bright, soft
            cachedColor = PushlingPalette.lerp(from: baseColor, to: PushlingPalette.bone, t: 0.3)
            cachedAlpha = 0.30
        case .fog:
            // Invisible — fog renderer handles atmosphere
            cachedColor = baseColor
            cachedAlpha = 0.0
        }
    }

    /// Apply cached appearance to all cloud nodes.
    private func applyAppearanceToAll() {
        for cloud in clouds {
            cloud.applyAppearance(color: cachedColor, alpha: cachedAlpha)
        }
    }

    // MARK: - Cloud Recycling

    /// Recycle a cloud that has left the viewport to the right side.
    private func recycleCloud(_ cloud: CloudNode, parallaxOffset: CGFloat) {
        let newConfig = randomConfig()
        cloud.rebuild(with: newConfig)

        // Place just beyond the right edge of the visible area
        let rightEdge = (Self.sceneWidth + Self.recyclePadding - parallaxOffset)
        cloud.worldX = rightEdge + CGFloat.random(in: 0...60)

        cloud.applyAppearance(color: cachedColor, alpha: cachedAlpha)
    }

    /// Generate randomized cloud parameters.
    private func randomConfig() -> CloudConfig {
        return CloudConfig(
            width: CGFloat.random(in: Self.minWidth...Self.maxWidth),
            driftSpeed: CGFloat.random(in: Self.minSpeed...Self.maxSpeed),
            bobAmplitude: Self.bobAmplitude * CGFloat.random(in: 0.7...1.3),
            bobPeriod: Self.bobPeriod * CGFloat.random(in: 0.8...1.2),
            yBase: CGFloat.random(in: Self.minY...Self.maxY),
            ellipseCount: Int.random(in: 3...5),
            bobPhase: CGFloat.random(in: 0...(2.0 * .pi))
        )
    }

    // MARK: - Query

    /// Current cloud count (for debug/MCP).
    var cloudCount: Int { clouds.count }

    /// Total child node count across all clouds (for performance monitoring).
    var totalNodeCount: Int {
        clouds.reduce(0) { $0 + $1.children.count }
    }
}
