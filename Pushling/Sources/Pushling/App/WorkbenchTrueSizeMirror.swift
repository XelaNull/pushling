// WorkbenchTrueSizeMirror.swift — WO-7 incr 2-3, dual view.
//
// SpriteKit does not support one live SKScene presented into two SKViews
// at once (a scene is owned by whichever view it's presented into; a
// second `presentScene` call elsewhere is undefined/breaks the first).
// So the true-size inset is NOT a second live view — it's a periodic
// TEXTURE SNAPSHOT of the one live (magnified) SKView, redrawn into an
// NSImageView sized at the scene's own true 1085x30pt dimensions.
//
// Architecture-agnostic: this snapshots whatever the scene currently
// renders (today's vector rig; later sprite frames) — nothing here is
// rig-specific.

import AppKit
import SpriteKit

final class WorkbenchTrueSizeMirror {

    /// Refresh cadence — a review aid, not a live 60fps mirror. Cheap at
    /// this scene's tiny (1085x30pt) size; 10Hz is comfortably below any
    /// frame-budget concern.
    private static let refreshInterval: TimeInterval = 0.1

    private weak var skView: SKView?
    private weak var scene: PushlingScene?
    private weak var targetImageView: NSImageView?
    private let sceneSize: CGSize

    private var timer: Timer?

    init(skView: SKView, scene: PushlingScene,
         targetImageView: NSImageView, sceneSize: CGSize) {
        self.skView = skView
        self.scene = scene
        self.targetImageView = targetImageView
        self.sceneSize = sceneSize
    }

    /// Begin the periodic refresh. Scheduled on the main run loop in
    /// `.common` mode so it keeps firing during window resize/menu
    /// tracking, not just the default run loop mode.
    func start() {
        let t = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // Prime immediately rather than waiting for the first tick.
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }

    /// Snapshot the live SKView's current frame and redraw it into the
    /// true-size inset. The NSImage's logical `size` is set to the
    /// scene's own true point dimensions REGARDLESS of the captured
    /// texture's actual pixel resolution — "true size" is a DISPLAY
    /// property (the inset's own fixed 1085x30pt frame), decoupled from
    /// whatever pixel density `texture(from:)` happens to produce from
    /// the (possibly magnified) source view.
    private func refresh() {
        guard let skView = skView, let scene = scene, let imageView = targetImageView else { return }
        guard let texture = skView.texture(from: scene) else { return }
        let cgImage = texture.cgImage()
        imageView.image = NSImage(cgImage: cgImage, size: sceneSize)
    }
}
