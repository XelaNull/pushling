// ZoomDetailController.swift — Zoom-dependent visual detail levels
// Manages 4 tiers of creature detail based on camera zoom level.
// Detail nodes are lazily created on first zoom-in, then cached.
// Hysteresis band (0.1) prevents flickering at tier boundaries.
//
// Tiers:
//   < 0.8   simplified — hide whiskers, toe pads, inner ears. Thinner strokes.
//   0.8-1.2 normal     — current rendering (no changes)
//   1.2-2.0 enhanced   — show toe pads on all paws, fur texture, whisker detail
//   > 2.0   maximum    — toe beans (4 per front paw), ear tufts, nose highlight

import SpriteKit

/// Visual detail tier based on zoom level.
enum ZoomDetailTier: Int, Comparable {
    case simplified = 0
    case normal = 1
    case enhanced = 2
    case maximum = 3

    static func < (lhs: ZoomDetailTier, rhs: ZoomDetailTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

final class ZoomDetailController {

    // MARK: - State

    /// Current active detail tier.
    private(set) var currentTier: ZoomDetailTier = .normal

    /// Hysteresis band — zoom must cross threshold ± this value to change tier.
    private static let hysteresis: CGFloat = 0.1

    // MARK: - Node References

    /// Nodes to hide in simplified mode.
    private var whiskerNodes: [SKNode] = []
    private var innerEarNodes: [SKNode] = []
    private var toePadNodes: [SKNode] = []
    // Legs are always visible — not zoom-gated

    /// Lazily-created detail nodes for enhanced/maximum tiers.
    private var toeBeanNodes: [SKShapeNode] = []
    private var earTuftNodes: [SKShapeNode] = []
    private var noseHighlightNode: SKShapeNode?

    /// Whether detail nodes have been created (lazy creation).
    private var hasCreatedMaxDetail = false

    /// Reference to creature head (for attaching ear tufts + nose highlight).
    private weak var headNode: SKNode?

    /// References to front paw nodes (for attaching toe beans).
    private weak var pawFLNode: SKNode?
    private weak var pawFRNode: SKNode?

    /// References to ear nodes (for attaching tufts).
    private weak var earLeftNode: SKNode?
    private weak var earRightNode: SKNode?

    /// Nose node (for highlight).
    private weak var noseNode: SKNode?

    /// Current growth stage (affects which details exist).
    private var stage: GrowthStage = .egg

    // MARK: - Configuration

    /// Configure with creature node references. Call from configureForStage().
    func configure(stage: GrowthStage, headNode: SKNode?,
                   pawFL: SKNode?, pawFR: SKNode?,
                   earLeft: SKNode?, earRight: SKNode?,
                   noseNode: SKNode?,
                   whiskerLeft: SKNode?, whiskerRight: SKNode?) {
        self.stage = stage
        self.headNode = headNode
        self.pawFLNode = pawFL
        self.pawFRNode = pawFR
        self.earLeftNode = earLeft
        self.earRightNode = earRight
        self.noseNode = noseNode

        // Collect existing detail nodes that can be toggled
        whiskerNodes.removeAll()
        innerEarNodes.removeAll()
        toePadNodes.removeAll()
        if let wl = whiskerLeft { whiskerNodes.append(wl) }
        if let wr = whiskerRight { whiskerNodes.append(wr) }

        // Find inner ear nodes
        if let el = earLeft,
           let inner = el.childNode(withName: "\(el.name ?? "")_inner") {
            innerEarNodes.append(inner)
        }
        if let er = earRight,
           let inner = er.childNode(withName: "\(er.name ?? "")_inner") {
            innerEarNodes.append(inner)
        }

        // Find toe pad nodes on all paws
        collectToePads(from: pawFL)
        collectToePads(from: pawFR)

        // Remove any previously created detail nodes
        removeMaxDetailNodes()
        hasCreatedMaxDetail = false
        currentTier = .normal
    }

    // MARK: - Per-Frame Update

    /// Update detail level based on current zoom. Called from PushlingScene.
    func update(zoomLevel: CGFloat) {
        let newTier = computeTier(zoom: zoomLevel)
        guard newTier != currentTier else { return }
        transition(to: newTier)
    }

    // MARK: - Tier Computation

    private func computeTier(zoom: CGFloat) -> ZoomDetailTier {
        let h = Self.hysteresis

        // Use hysteresis: only cross a boundary if zoom exceeds
        // threshold + hysteresis (going up) or drops below
        // threshold - hysteresis (going down).
        switch currentTier {
        case .simplified:
            if zoom >= 0.8 + h { return .normal }
            return .simplified
        case .normal:
            if zoom < 0.8 - h { return .simplified }
            if zoom >= 1.2 + h { return .enhanced }
            return .normal
        case .enhanced:
            if zoom < 1.2 - h { return .normal }
            if zoom >= 2.0 + h { return .maximum }
            return .enhanced
        case .maximum:
            if zoom < 2.0 - h { return .enhanced }
            return .maximum
        }
    }

    // MARK: - Tier Transitions

    private func transition(to tier: ZoomDetailTier) {
        let old = currentTier
        currentTier = tier

        switch tier {
        case .simplified:
            applySimplified()
        case .normal:
            applyNormal()
        case .enhanced:
            applyEnhanced()
        case .maximum:
            if !hasCreatedMaxDetail {
                createMaxDetailNodes()
                hasCreatedMaxDetail = true
            }
            applyMaximum()
        }

        NSLog("[Pushling/ZoomDetail] Tier %d → %d", old.rawValue,
              tier.rawValue)
    }

    // MARK: - Simplified (< 0.8x)

    private func applySimplified() {
        // Hide whiskers, toe pads, inner ears
        for node in whiskerNodes { node.alpha = 0 }
        for node in innerEarNodes { node.alpha = 0 }
        for node in toePadNodes { node.alpha = 0 }

        // Hide max-detail nodes
        hideMaxDetailNodes()
    }

    // MARK: - Normal (0.8x - 1.2x)

    private func applyNormal() {
        // Restore whiskers, inner ears
        for node in whiskerNodes { node.alpha = 1.0 }
        for node in innerEarNodes { node.alpha = 0.4 }

        // Restore toe pads on front paws only (Beast+)
        for node in toePadNodes { node.alpha = 0.3 }

        // Hide max-detail nodes
        hideMaxDetailNodes()
    }

    // MARK: - Enhanced (1.2x - 2.0x)

    private func applyEnhanced() {
        // Full whisker and ear detail
        for node in whiskerNodes { node.alpha = 1.0 }
        for node in innerEarNodes { node.alpha = 0.5 }

        // Show toe pads on all paws with better visibility
        for node in toePadNodes { node.alpha = 0.45 }

        // Hide max-detail nodes
        hideMaxDetailNodes()
    }

    // MARK: - Maximum (> 2.0x)

    private func applyMaximum() {
        // Full detail everything
        for node in whiskerNodes { node.alpha = 1.0 }
        for node in innerEarNodes { node.alpha = 0.55 }
        for node in toePadNodes { node.alpha = 0.5 }

        // Show max-detail nodes
        for node in toeBeanNodes { node.alpha = 0.35 }
        for node in earTuftNodes { node.alpha = 0.5 }
        noseHighlightNode?.alpha = 0.3
    }

    // MARK: - Max Detail Node Creation (Lazy)

    private func createMaxDetailNodes() {
        guard stage >= .critter else { return }
        let config = StageConfiguration.all[stage]!

        // Toe beans on front paws (4 per paw)
        if let fl = pawFLNode {
            let pawSize = stage >= .beast ? CGFloat(2.5) : CGFloat(2.0)
            let beans = CatShapes.toeBeans(pawSize: pawSize)
            for (i, path) in beans.enumerated() {
                let bean = SKShapeNode(path: path)
                bean.fillColor = PushlingPalette.softEmber
                bean.strokeColor = .clear
                bean.alpha = 0
                bean.name = "toe_bean_fl_\(i)"
                bean.zPosition = 1
                fl.addChild(bean)
                toeBeanNodes.append(bean)
            }
        }
        if let fr = pawFRNode {
            let pawSize = stage >= .beast ? CGFloat(2.5) : CGFloat(2.0)
            let beans = CatShapes.toeBeans(pawSize: pawSize)
            for (i, path) in beans.enumerated() {
                let bean = SKShapeNode(path: path)
                bean.fillColor = PushlingPalette.softEmber
                bean.strokeColor = .clear
                bean.alpha = 0
                bean.name = "toe_bean_fr_\(i)"
                bean.zPosition = 1
                fr.addChild(bean)
                toeBeanNodes.append(bean)
            }
        }

        // Ear tufts
        if let el = earLeftNode as? SKShapeNode {
            let earH = config.size.width * 0.3
            let tuftPath = CatShapes.earTuft(earHeight: earH)
            let tuft = SKShapeNode(path: tuftPath)
            tuft.strokeColor = PushlingPalette.ash
            tuft.lineWidth = 0.4
            tuft.alpha = 0
            tuft.name = "ear_tuft_left"
            tuft.zPosition = 1
            el.addChild(tuft)
            earTuftNodes.append(tuft)
        }
        if let er = earRightNode as? SKShapeNode {
            let earH = config.size.width * 0.3
            let tuftPath = CatShapes.earTuft(earHeight: earH)
            let tuft = SKShapeNode(path: tuftPath)
            tuft.strokeColor = PushlingPalette.ash
            tuft.lineWidth = 0.4
            tuft.alpha = 0
            tuft.name = "ear_tuft_right"
            tuft.zPosition = 1
            er.addChild(tuft)
            earTuftNodes.append(tuft)
        }

        // Nose wet highlight
        if let nose = noseNode {
            let highlightSize = config.size.width * 0.02
            let highlight = SKShapeNode(circleOfRadius: highlightSize)
            highlight.fillColor = PushlingPalette.bone
            highlight.strokeColor = .clear
            highlight.alpha = 0
            highlight.name = "nose_highlight"
            highlight.zPosition = 1
            highlight.position = CGPoint(x: highlightSize * 0.3,
                                          y: highlightSize * 0.2)
            nose.addChild(highlight)
            noseHighlightNode = highlight
        }
    }

    private func hideMaxDetailNodes() {
        for node in toeBeanNodes { node.alpha = 0 }
        for node in earTuftNodes { node.alpha = 0 }
        noseHighlightNode?.alpha = 0
    }

    private func removeMaxDetailNodes() {
        for node in toeBeanNodes { node.removeFromParent() }
        for node in earTuftNodes { node.removeFromParent() }
        noseHighlightNode?.removeFromParent()
        toeBeanNodes.removeAll()
        earTuftNodes.removeAll()
        noseHighlightNode = nil
    }

    // MARK: - Helpers

    private func collectToePads(from paw: SKNode?) {
        guard let paw = paw else { return }
        for child in paw.children {
            if let shape = child as? SKShapeNode,
               let name = shape.name, name.contains("toe_") {
                toePadNodes.append(shape)
            }
        }
    }
}
