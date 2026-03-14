// PushlingScene.swift — Main SpriteKit scene for the Touch Bar
// Size: 1085 x 30 points (2170 x 60 pixels @2x Retina)
// Runs at 60fps with frame budget monitoring.

import SpriteKit

final class PushlingScene: SKScene {

    // MARK: - Frame Budget Monitor

    private let frameBudgetMonitor = FrameBudgetMonitor()
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Debug Overlay

    private var debugOverlayNode: SKLabelNode?
    private var isDebugOverlayVisible = false

    // MARK: - Test Node (Phase 1 visual confirmation)

    private var testNode: SKShapeNode?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        setupTestNode()
        setupDebugOverlay()

        NSLog("[Pushling] Scene active — \(Int(size.width))x\(Int(size.height))pt")
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime: TimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 1.0 / 60.0  // First frame: assume 60fps
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        // Start frame timing
        frameBudgetMonitor.beginFrame()

        // === Subsystem update order (skeleton for Phase 2+) ===
        // 1. Physics — collision detection, force application
        updatePhysics(deltaTime: deltaTime)

        // 2. State — creature AI, emotional state, growth checks
        updateState(deltaTime: deltaTime)

        // 3. Render — animation advancement, particle updates, camera
        updateRender(deltaTime: deltaTime)

        // End frame timing and check budget
        frameBudgetMonitor.endFrame()

        // Update debug overlay if visible
        if isDebugOverlayVisible {
            updateDebugOverlayText()
        }
    }

    // MARK: - Subsystem Stubs (Phase 2+)

    /// Phase 2: Physics — collision detection, creature jump arcs, rain particles
    private func updatePhysics(deltaTime: TimeInterval) {
        // Intentionally empty — Phase 2
    }

    /// Phase 2: State — creature AI, emotions, hunger, growth
    private func updateState(deltaTime: TimeInterval) {
        // Intentionally empty — Phase 2
    }

    /// Phase 2: Render — animation frames, parallax, weather, camera
    private func updateRender(deltaTime: TimeInterval) {
        // Intentionally empty — Phase 2
    }

    // MARK: - Test Node

    /// A small visible node to confirm SpriteKit rendering works on the Touch Bar.
    /// This will be replaced by the creature node in Phase 2.
    private func setupTestNode() {
        let node = SKShapeNode(circleOfRadius: 8)
        node.fillColor = SKColor.white
        node.strokeColor = SKColor.clear
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.name = "testNode"

        // Gentle breathing animation — the creature must ALWAYS breathe
        let breatheUp = SKAction.scaleY(to: 1.03, duration: 1.25)
        breatheUp.timingMode = .easeInEaseOut
        let breatheDown = SKAction.scaleY(to: 1.0, duration: 1.25)
        breatheDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([breatheUp, breatheDown])
        node.run(SKAction.repeatForever(breathe), withKey: "breathe")

        addChild(node)
        self.testNode = node
    }

    // MARK: - Debug Overlay

    private func setupDebugOverlay() {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 9
        label.fontColor = SKColor.green
        label.horizontalAlignmentMode = .right
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: size.width - 4, y: size.height - 2)
        label.name = "debugOverlay"
        label.zPosition = 1000  // Always on top
        label.isHidden = true
        label.text = "-- fps | --ms | 0 nodes"

        addChild(label)
        self.debugOverlayNode = label
    }

    func showDebugOverlay(_ show: Bool) {
        isDebugOverlayVisible = show
        debugOverlayNode?.isHidden = !show

        // Also toggle SpriteKit's built-in debug info on the SKView
        if let view = self.view {
            view.showsFPS = show
            view.showsNodeCount = show
        }
    }

    private func updateDebugOverlayText() {
        let stats = frameBudgetMonitor.currentStats
        let fpsStr = String(format: "%.0f", stats.fps)
        let frameTimeStr = String(format: "%.1f", stats.averageFrameTimeMs)
        let nodeCount = children.count

        debugOverlayNode?.text = "\(fpsStr)fps | \(frameTimeStr)ms | \(nodeCount) nodes"
    }
}
