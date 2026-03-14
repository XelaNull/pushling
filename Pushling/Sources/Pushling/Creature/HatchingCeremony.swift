// HatchingCeremony.swift — The 30-second first-launch experience
// The creature is born from the developer's git history.
//
// Three phases:
//   Phase 1 (0-20s): Git history montage — repo names, language badges, counts
//   Phase 2 (20-27s): Materialization — pixel of light grows into Spore
//   Phase 3 (27-30s): Naming — name appears above the creature
//
// The ceremony plays ONCE in the creature's lifetime. If the app is quit
// during the ceremony, the creature is still created (state saved before start).

import SpriteKit

// MARK: - Hatching Ceremony

/// Orchestrates the 30-second hatching ceremony on the Touch Bar.
/// Runs on the main thread (SpriteKit scene update loop).
final class HatchingCeremony {

    // MARK: - Phase

    enum Phase {
        case notStarted
        case montage        // 0-20s: git history scrolls past
        case materialization // 20-27s: spore forms from light
        case naming         // 27-30s: name appears
        case complete
    }

    // MARK: - State

    private(set) var phase: Phase = .notStarted
    private var elapsed: TimeInterval = 0
    private var isRunning = false

    /// The scene to add ceremony nodes to.
    private weak var scene: SKScene?

    /// The scan result (fed in as it completes).
    private var scanResult: GitScanResult?

    /// The generated name.
    private(set) var creatureName: String = ""

    /// The computed personality.
    private(set) var personality: Personality = .neutral

    /// The computed visual traits.
    private(set) var visualTraits: VisualTraits = .neutral

    /// Callback when ceremony completes.
    var onComplete: ((String, Personality, VisualTraits) -> Void)?

    // MARK: - Ceremony Nodes

    private var montageContainer: SKNode?
    private var sporeNode: SKShapeNode?
    private var nameLabel: SKLabelNode?
    private var dataSparkEmitter: SKNode?

    // MARK: - Montage State

    /// Items to display in the montage, fed progressively from the scanner.
    private var montageItems: [MontageItem] = []
    private var montageScrollX: CGFloat = 0
    private var montageSpeed: CGFloat = 30  // pts/sec, accelerates

    /// Index of next montage item to spawn.
    private var nextMontageItem = 0

    /// Interval between spawning montage items.
    private var montageSpawnInterval: TimeInterval = 1.5
    private var montageSpawnTimer: TimeInterval = 0

    // MARK: - Phase Timing

    private static let montageDuration: TimeInterval = 20.0
    private static let materializationDuration: TimeInterval = 7.0
    private static let namingDuration: TimeInterval = 3.0
    private static let totalDuration: TimeInterval = 30.0

    // MARK: - Init

    init(scene: SKScene) {
        self.scene = scene
    }

    // MARK: - Start

    /// Begin the hatching ceremony.
    /// Call this after initiating the git scan on a background thread.
    func begin() {
        guard !isRunning else { return }
        isRunning = true
        phase = .montage
        elapsed = 0

        setupMontageContainer()
        NSLog("[Pushling/Hatch] Ceremony began")
    }

    /// Feed scan results into the ceremony (can be called incrementally).
    func feedScanResult(_ result: GitScanResult) {
        self.scanResult = result
        self.personality = result.personality
        self.visualTraits = result.visualTraits

        // Generate name
        creatureName = NameGenerator.generateFromSystem()

        // Build montage items from scan data
        buildMontageItems(from: result)

        NSLog("[Pushling/Hatch] Scan result received — %d repos, "
              + "name: %@", result.repoCount, creatureName)
    }

    // MARK: - Update

    /// Called each frame during the ceremony.
    /// - Parameter deltaTime: Seconds since last frame.
    func update(deltaTime: TimeInterval) {
        guard isRunning else { return }

        elapsed += deltaTime

        switch phase {
        case .notStarted:
            break

        case .montage:
            updateMontage(deltaTime: deltaTime)
            if elapsed >= Self.montageDuration {
                transitionToMaterialization()
            }

        case .materialization:
            updateMaterialization(deltaTime: deltaTime)
            let matElapsed = elapsed - Self.montageDuration
            if matElapsed >= Self.materializationDuration {
                transitionToNaming()
            }

        case .naming:
            updateNaming(deltaTime: deltaTime)
            let nameElapsed = elapsed - Self.montageDuration
                - Self.materializationDuration
            if nameElapsed >= Self.namingDuration {
                complete()
            }

        case .complete:
            break
        }
    }

    // MARK: - Montage Phase (0-20s)

    private func setupMontageContainer() {
        guard let scene = scene else { return }

        let container = SKNode()
        container.name = "hatch_montage"
        container.zPosition = 100  // Above everything
        scene.addChild(container)
        self.montageContainer = container

        // Add data-spark background particles
        let sparks = SKNode()
        sparks.name = "hatch_sparks"
        scene.addChild(sparks)
        self.dataSparkEmitter = sparks
    }

    private func updateMontage(deltaTime: TimeInterval) {
        // Accelerate scroll speed over time
        let progress = elapsed / Self.montageDuration
        montageSpeed = 30.0 + CGFloat(progress) * 170.0  // 30 -> 200 pts/sec

        // Scroll existing items
        montageContainer?.children.forEach { node in
            node.position.x -= montageSpeed * CGFloat(deltaTime)

            // Remove items that scroll off the left edge
            if node.position.x < -200 {
                node.removeFromParent()
            }
        }

        // Spawn new montage items
        montageSpawnTimer += deltaTime

        // Spawn interval decreases as speed increases
        montageSpawnInterval = max(0.3, 1.5 - progress * 1.2)

        if montageSpawnTimer >= montageSpawnInterval {
            montageSpawnTimer = 0
            spawnNextMontageItem()
        }

        // Near the end (last 2s), converge all items toward center
        if elapsed > Self.montageDuration - 2.0 {
            let convergeFactor = CGFloat(
                (elapsed - (Self.montageDuration - 2.0)) / 2.0
            )
            let centerX = (scene?.size.width ?? 1085) / 2
            let centerY = (scene?.size.height ?? 30) / 2

            montageContainer?.children.forEach { node in
                let dx = centerX - node.position.x
                let dy = centerY - node.position.y
                node.position.x += dx * convergeFactor * CGFloat(deltaTime) * 3
                node.position.y += dy * convergeFactor * CGFloat(deltaTime) * 3
                node.alpha = max(0, 1.0 - convergeFactor * 0.8)
            }
        }

        // Background data sparks
        spawnDataSpark()
    }

    private func spawnNextMontageItem() {
        guard let container = montageContainer,
              let scene = scene else { return }

        let sceneWidth = scene.size.width
        let sceneHeight = scene.size.height

        // If we have scan data, use it; otherwise show placeholder
        if nextMontageItem < montageItems.count {
            let item = montageItems[nextMontageItem]
            nextMontageItem += 1

            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.fontSize = item.fontSize
            label.fontColor = item.color
            label.text = item.text
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(
                x: sceneWidth + 10,
                y: CGFloat.random(in: 5...(sceneHeight - 5))
            )
            label.alpha = 0.9
            container.addChild(label)
        } else if scanResult == nil {
            // No scan data yet — show scanning indicator
            let dots = String(repeating: ".", count: (nextMontageItem % 3) + 1)
            let label = SKLabelNode(fontNamed: "Menlo")
            label.fontSize = 8
            label.fontColor = PushlingPalette.ash
            label.text = "scanning\(dots)"
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(
                x: sceneWidth + 10,
                y: sceneHeight / 2
            )
            container.addChild(label)
            nextMontageItem += 1
        }
    }

    private func spawnDataSpark() {
        guard let sparks = dataSparkEmitter,
              let scene = scene,
              sparks.children.count < 20 else { return }

        // 15% chance per frame
        guard Double.random(in: 0...1) < 0.15 else { return }

        let spark = SKShapeNode(circleOfRadius: 0.5)
        spark.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.4)
        spark.strokeColor = .clear
        spark.position = CGPoint(
            x: CGFloat.random(in: 0...scene.size.width),
            y: CGFloat.random(in: 0...scene.size.height)
        )

        sparks.addChild(spark)

        let fade = SKAction.fadeOut(withDuration: 1.5)
        let remove = SKAction.removeFromParent()
        spark.run(SKAction.sequence([fade, remove]))
    }

    // MARK: - Materialization Phase (20-27s)

    private func transitionToMaterialization() {
        phase = .materialization

        // Remove montage
        montageContainer?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
        montageContainer = nil

        // Create the initial pixel of light
        guard let scene = scene else { return }
        let centerX = scene.size.width / 2
        let centerY = scene.size.height / 2

        let spore = SKShapeNode(circleOfRadius: 0.5)
        spore.fillColor = PushlingPalette.bone
        spore.strokeColor = .clear
        spore.position = CGPoint(x: centerX, y: centerY)
        spore.zPosition = 100
        spore.alpha = 0.8
        spore.name = "hatch_spore"
        scene.addChild(spore)
        self.sporeNode = spore

        NSLog("[Pushling/Hatch] Materialization phase")
    }

    private func updateMaterialization(deltaTime: TimeInterval) {
        guard let spore = sporeNode else { return }

        let matElapsed = elapsed - Self.montageDuration
        let progress = matElapsed / Self.materializationDuration

        // Grow the spore: 0.5px -> 3px radius over 7 seconds
        let radius = 0.5 + progress * 2.5

        // Recreate the shape (SKShapeNode path can't be resized smoothly)
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(
            x: -radius, y: -radius,
            width: radius * 2, height: radius * 2
        ))
        spore.path = path

        // Breathing from the start — this is the first breath!
        let breathScale = 1.0 + 0.03
            * CGFloat(sin(2.0 * .pi * matElapsed / 2.5))
        spore.yScale = breathScale

        // Color shift: cycle through palette before settling
        if progress < 0.7 {
            // Cycling colors
            let huePhase = matElapsed * 0.8
            let hue = CGFloat(huePhase.truncatingRemainder(dividingBy: 1.0))
            spore.fillColor = SKColor(hue: hue, saturation: 0.6,
                                       brightness: 1.0, alpha: 1.0)
        } else {
            // Settling toward creature's base color
            let settleProgress = (progress - 0.7) / 0.3
            let targetHue = CGFloat(visualTraits.baseColorHue)
            let currentHue = CGFloat(
                matElapsed.truncatingRemainder(dividingBy: 1.0)
            )
            let finalHue = currentHue + (targetHue - currentHue)
                * CGFloat(settleProgress)
            spore.fillColor = SKColor(
                hue: finalHue, saturation: 0.5,
                brightness: 1.0, alpha: 0.9
            )
        }

        // Faint particle halo in the middle
        if progress > 0.3 && progress < 0.8 {
            spawnMaterializationParticle(around: spore)
        }

        // Alpha pulsing
        spore.alpha = CGFloat(0.7 + 0.3 * sin(matElapsed * 3.0))
    }

    private func spawnMaterializationParticle(around node: SKNode) {
        guard let scene = scene,
              Double.random(in: 0...1) < 0.3 else { return }

        let particle = SKShapeNode(circleOfRadius: 0.3)
        particle.fillColor = PushlingPalette.gilt
        particle.strokeColor = .clear
        particle.alpha = 0.5

        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist = CGFloat.random(in: 5...15)
        particle.position = CGPoint(
            x: node.position.x + cos(angle) * dist,
            y: node.position.y + sin(angle) * dist
        )
        particle.zPosition = 99
        scene.addChild(particle)

        // Drift toward center and fade
        let moveAction = SKAction.move(to: node.position, duration: 1.5)
        let fadeAction = SKAction.fadeOut(withDuration: 1.5)
        let group = SKAction.group([moveAction, fadeAction])
        let remove = SKAction.removeFromParent()
        particle.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Naming Phase (27-30s)

    private func transitionToNaming() {
        phase = .naming

        guard let scene = scene,
              let spore = sporeNode else { return }

        // Spore pulses warmly
        spore.fillColor = SKColor(
            hue: CGFloat(visualTraits.baseColorHue),
            saturation: 0.5, brightness: 1.0, alpha: 0.9
        )

        // Name appears above
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 9
        label.fontColor = PushlingPalette.gilt
        label.text = creatureName
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .bottom
        label.position = CGPoint(
            x: spore.position.x,
            y: spore.position.y + 6
        )
        label.zPosition = 101
        label.alpha = 0
        label.name = "hatch_name"
        scene.addChild(label)
        self.nameLabel = label

        // Fade in
        label.run(SKAction.fadeIn(withDuration: 0.8))

        NSLog("[Pushling/Hatch] Naming phase — '%@'", creatureName)
    }

    private func updateNaming(deltaTime: TimeInterval) {
        guard let spore = sporeNode else { return }

        // Warm pulse
        let nameElapsed = elapsed - Self.montageDuration
            - Self.materializationDuration
        let pulseAlpha = 0.8 + 0.2 * CGFloat(sin(nameElapsed * 2.0))
        spore.alpha = pulseAlpha

        // Continue breathing
        let breathScale = 1.0 + 0.03
            * CGFloat(sin(2.0 * .pi * elapsed / 2.5))
        spore.yScale = breathScale

        // Fade name after 2 seconds
        if nameElapsed > 2.0 {
            let fadeProgress = (nameElapsed - 2.0) / 1.0
            nameLabel?.alpha = CGFloat(max(0, 1.0 - fadeProgress))
        }
    }

    // MARK: - Completion

    private func complete() {
        phase = .complete
        isRunning = false

        // Clean up ceremony nodes
        nameLabel?.removeFromParent()
        dataSparkEmitter?.removeFromParent()
        // Spore node is left — it becomes the actual creature

        NSLog("[Pushling/Hatch] Ceremony complete — '%@' is born",
              creatureName)

        onComplete?(creatureName, personality, visualTraits)
    }

    /// Whether the ceremony is currently running.
    var isCeremonyActive: Bool { isRunning }

    /// Whether the ceremony has completed.
    var isComplete: Bool { phase == .complete }

    /// Current progress (0.0 to 1.0).
    var progress: Double {
        elapsed / Self.totalDuration
    }

    // MARK: - Cleanup

    /// Force-cleanup all ceremony nodes (e.g., if app quits mid-ceremony).
    func cleanup() {
        montageContainer?.removeFromParent()
        sporeNode?.removeFromParent()
        nameLabel?.removeFromParent()
        dataSparkEmitter?.removeFromParent()
        isRunning = false
        phase = .complete
    }

    // MARK: - Montage Item Building

    /// A single item in the scrolling montage.
    private struct MontageItem {
        let text: String
        let color: SKColor
        let fontSize: CGFloat
    }

    /// Build montage items from scan results.
    private func buildMontageItems(from result: GitScanResult) {
        montageItems.removeAll()

        // Repo names (large, Tide color)
        for (name, commits) in result.repoCommitCounts.prefix(20) {
            montageItems.append(MontageItem(
                text: "\(name) (\(commits))",
                color: PushlingPalette.tide,
                fontSize: 10
            ))
        }

        // Language badges (medium, colored dots)
        for (lang, count) in result.languageCounts.prefix(15) {
            let color = languageColor(for: lang)
            montageItems.append(MontageItem(
                text: ".\(lang) ×\(count)",
                color: color,
                fontSize: 8
            ))
        }

        // Stats (small, Ash color)
        montageItems.append(MontageItem(
            text: "\(result.totalCommits) commits",
            color: PushlingPalette.gilt,
            fontSize: 9
        ))

        if result.totalLinesAdded > 0 {
            let totalLines = result.totalLinesAdded + result.totalLinesDeleted
            montageItems.append(MontageItem(
                text: "+\(result.totalLinesAdded) -\(result.totalLinesDeleted)",
                color: PushlingPalette.moss,
                fontSize: 7
            ))

            montageItems.append(MontageItem(
                text: "\(totalLines) lines touched",
                color: PushlingPalette.ash,
                fontSize: 7
            ))
        }

        montageItems.append(MontageItem(
            text: "\(result.repoCount) repos",
            color: PushlingPalette.ash,
            fontSize: 8
        ))

        // Shuffle for visual variety (but keep first few repo names up front)
        if montageItems.count > 5 {
            let header = Array(montageItems.prefix(3))
            var rest = Array(montageItems.dropFirst(3))
            rest.shuffle()
            montageItems = header + rest
        }
    }

    /// Get a display color for a file extension.
    private func languageColor(for ext: String) -> SKColor {
        if let cat = LanguageCategory.extensionMap[ext] {
            let hue = CGFloat(cat.baseColorHue)
            return SKColor(hue: hue, saturation: 0.7,
                            brightness: 1.0, alpha: 0.9)
        }
        return PushlingPalette.ash
    }
}

// MARK: - Empty Scan Montage

extension HatchingCeremony {

    /// Create a gentle "empty" montage for developers with no git history.
    func feedEmptyResult() {
        scanResult = .empty
        personality = .neutral
        visualTraits = .neutral
        creatureName = NameGenerator.generateFromSystem()

        montageItems = [
            MontageItem(
                text: "No commits yet.",
                color: PushlingPalette.ash,
                fontSize: 8
            ),
            MontageItem(
                text: "That's okay.",
                color: PushlingPalette.bone,
                fontSize: 8
            ),
            MontageItem(
                text: "Every story starts somewhere.",
                color: PushlingPalette.gilt,
                fontSize: 9
            ),
        ]
    }
}
