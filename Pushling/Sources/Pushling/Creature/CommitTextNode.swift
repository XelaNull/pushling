// CommitTextNode.swift — Individual character nodes for commit text display
// Each character is a separate SKLabelNode (max 20 chars).
// Nodes are recycled from a pre-allocated pool to keep count predictable.
//
// Text selection: first 20 chars of commit message, conventional prefixes
// stripped, padded with SHA if short, first char capitalized.

import SpriteKit

// MARK: - Commit Text Node

/// Container for individual character nodes representing the commit message.
final class CommitTextNode: SKNode {

    /// Individual character label nodes.
    private(set) var charNodes: [SKLabelNode] = []

    /// Total text being displayed.
    private(set) var displayText: String = ""

    /// Active font size (set during configure).
    private(set) var activeFontSize: CGFloat = 7.5

    /// Active character spacing (set during configure).
    private(set) var activeSpacing: CGFloat = 5

    /// Pool of reusable character nodes (max 20).
    private static let poolSize = 20
    private var nodePool: [SKLabelNode] = []

    // MARK: - Initialization

    override init() {
        super.init()
        self.name = "commitText"
        self.zPosition = 35

        // Pre-create the node pool
        for i in 0..<Self.poolSize {
            let label = SKLabelNode(fontNamed: "SFProText-Bold")
            label.fontSize = 7.5
            label.fontColor = PushlingPalette.tide
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.name = "char_\(i)"
            label.isHidden = true
            nodePool.append(label)
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Configure

    /// Configure the text display from a commit message.
    /// - Parameters:
    ///   - message: The commit message.
    ///   - sha: The commit SHA (used as fallback padding).
    ///   - fontSize: Font size in points (default 7.5).
    func configure(message: String, sha: String, fontSize: CGFloat = 7.5) {
        self.activeFontSize = fontSize
        self.activeSpacing = fontSize * 0.67
        // Select text: first 20 chars of message
        var text = message.trimmingCharacters(in: .whitespaces)

        // Strip conventional commit prefixes
        let prefixes = ["feat:", "fix:", "chore:", "docs:", "style:",
                        "refactor:", "test:", "ci:", "perf:", "build:"]
        for prefix in prefixes {
            if text.lowercased().hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Pad short messages with SHA
        if text.count < 8 {
            let padding = String(sha.prefix(8 - text.count))
            text = text + " " + padding
        }

        // Capitalize first character
        if let first = text.first {
            text = first.uppercased() + String(text.dropFirst())
        }

        // Truncate to 20 chars
        text = String(text.prefix(20))
        displayText = text

        // Configure character nodes
        let spacing = activeSpacing
        charNodes = []

        for (i, char) in text.enumerated() {
            guard i < nodePool.count else { break }
            let node = nodePool[i]
            node.text = String(char)
            node.fontSize = fontSize
            node.position = CGPoint(
                x: CGFloat(i) * spacing, y: 0
            )
            node.alpha = 0
            node.isHidden = false
            node.setScale(1.0)
            node.fontColor = PushlingPalette.tide
            charNodes.append(node)
        }

        // Hide unused pool nodes
        for i in text.count..<nodePool.count {
            nodePool[i].isHidden = true
        }
    }

    /// Reset all character nodes for reuse.
    func resetAll() {
        for node in nodePool {
            node.isHidden = true
            node.alpha = 0
            node.setScale(1.0)
            node.fontColor = PushlingPalette.tide
        }
        charNodes = []
        displayText = ""
    }
}
