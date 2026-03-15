// VisualEventBuilders.swift — SpriteKit node builders for 7 visual events
// P3-T3-09: Extension on VisualEventManager with event-specific builders.
//
// Each builder creates SKNode compositions for one event type.
// All colors from P3 palette. Node budget: max 15 nodes per event.

import SpriteKit

// MARK: - Event Builders

extension VisualEventManager {

    // MARK: - Shooting Star

    func buildShootingStar() {
        let star = SKShapeNode(circleOfRadius: 1.5)
        star.fillColor = PushlingPalette.gilt
        star.strokeColor = .clear
        star.position = CGPoint(x: -20, y: CGFloat.random(in: 18...28))
        star.zPosition = 1
        eventContainer.addChild(star)
        activeNodes.append(star)

        // Trail particles (3 nodes)
        for i in 0..<3 {
            let trail = SKShapeNode(circleOfRadius: 0.8 - CGFloat(i) * 0.2)
            trail.fillColor = PushlingPalette.withAlpha(
                PushlingPalette.gilt, alpha: 0.6 - CGFloat(i) * 0.15
            )
            trail.strokeColor = .clear
            trail.position = star.position
            trail.zPosition = 0
            eventContainer.addChild(trail)
            activeNodes.append(trail)

            let delay = TimeInterval(i + 1) * 0.08
            trail.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.moveTo(x: Self.sceneWidth + 40, duration: 1.5 - delay),
                SKAction.fadeAlpha(to: 0, duration: 0.3)
            ]))
        }

        // Main star movement
        let moveAction = SKAction.moveTo(x: Self.sceneWidth + 40, duration: 1.5)
        moveAction.timingMode = .easeIn

        // Flash at end
        let flash = SKShapeNode(circleOfRadius: 4)
        flash.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.8)
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.position = CGPoint(x: Self.sceneWidth * 0.8, y: star.position.y - 5)
        flash.zPosition = 2
        eventContainer.addChild(flash)
        activeNodes.append(flash)

        star.run(SKAction.sequence([
            moveAction,
            SKAction.fadeAlpha(to: 0, duration: 0.1)
        ]))

        flash.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.3),
            SKAction.fadeAlpha(to: 0.8, duration: 0.1),
            SKAction.fadeAlpha(to: 0, duration: 0.5)
        ]))
    }

    // MARK: - Aurora

    func buildAurora() {
        let colors: [SKColor] = [
            PushlingPalette.withAlpha(PushlingPalette.moss, alpha: 0.15),
            PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.12),
            PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.10),
            PushlingPalette.withAlpha(PushlingPalette.moss, alpha: 0.12),
            PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.08),
        ]

        for (i, color) in colors.enumerated() {
            let bar = SKShapeNode(
                rectOf: CGSize(width: Self.sceneWidth * 0.6, height: 4)
            )
            bar.fillColor = color
            bar.strokeColor = .clear
            bar.position = CGPoint(
                x: Self.sceneWidth * 0.3 + CGFloat(i) * 40,
                y: Self.sceneHeight - 3 - CGFloat(i) * 1.5
            )
            bar.zPosition = CGFloat(i)
            eventContainer.addChild(bar)
            activeNodes.append(bar)

            bar.alpha = 0
            bar.run(SKAction.fadeAlpha(to: 1.0, duration: 3.0))

            let waveUp = SKAction.moveBy(x: 0, y: 2,
                                          duration: 3.0 + Double(i) * 0.5)
            waveUp.timingMode = .easeInEaseOut
            let waveDown = SKAction.moveBy(x: 0, y: -2,
                                            duration: 3.0 + Double(i) * 0.5)
            waveDown.timingMode = .easeInEaseOut
            let drift = SKAction.moveBy(x: CGFloat.random(in: -30...30), y: 0,
                                         duration: 8.0)
            drift.timingMode = .easeInEaseOut
            let driftBack = drift.reversed()

            bar.run(SKAction.repeatForever(
                SKAction.sequence([waveUp, waveDown])
            ), withKey: "wave")
            bar.run(SKAction.repeatForever(
                SKAction.sequence([drift, driftBack])
            ), withKey: "drift")
        }
    }

    // MARK: - Bloom

    func buildBloom() {
        for i in 0..<8 {
            let particle = SKShapeNode(circleOfRadius: 1.0)
            particle.fillColor = PushlingPalette.moss
            particle.strokeColor = .clear
            particle.alpha = 0

            let startX = CGFloat.random(in: 100...(Self.sceneWidth - 100))
            particle.position = CGPoint(x: startX, y: 4)
            particle.zPosition = 1
            eventContainer.addChild(particle)
            activeNodes.append(particle)

            let delay = Double(i) * 0.15
            let riseHeight = CGFloat.random(in: 10...20)
            let drift = CGFloat.random(in: -15...15)

            particle.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0.8, duration: 0.3),
                    SKAction.moveBy(x: drift, y: riseHeight, duration: 2.0),
                ]),
                SKAction.group([
                    SKAction.fadeAlpha(to: 0, duration: 1.5),
                    SKAction.moveBy(x: drift * 0.5, y: 5, duration: 1.5),
                ])
            ]))
        }

        // Brief green pulse across the scene
        let pulse = SKShapeNode(
            rectOf: CGSize(width: Self.sceneWidth + 20, height: Self.sceneHeight + 10)
        )
        pulse.fillColor = PushlingPalette.withAlpha(PushlingPalette.moss,
                                                     alpha: 0.15)
        pulse.strokeColor = .clear
        pulse.position = CGPoint(x: Self.sceneWidth / 2,
                                  y: Self.sceneHeight / 2)
        pulse.alpha = 0
        pulse.zPosition = -1
        eventContainer.addChild(pulse)
        activeNodes.append(pulse)

        pulse.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 0.5),
            SKAction.fadeAlpha(to: 0, duration: 2.0)
        ]))
    }

    // MARK: - Eclipse

    func buildEclipse() {
        let darken = SKShapeNode(
            rectOf: CGSize(width: Self.sceneWidth + 20,
                           height: Self.sceneHeight + 10)
        )
        darken.fillColor = PushlingPalette.void_
        darken.strokeColor = .clear
        darken.position = CGPoint(x: Self.sceneWidth / 2,
                                   y: Self.sceneHeight / 2)
        darken.alpha = 0
        darken.zPosition = -2
        eventContainer.addChild(darken)
        activeNodes.append(darken)

        let tint = SKShapeNode(
            rectOf: CGSize(width: Self.sceneWidth + 20,
                           height: Self.sceneHeight + 10)
        )
        tint.fillColor = PushlingPalette.dusk
        tint.strokeColor = .clear
        tint.position = darken.position
        tint.alpha = 0
        tint.zPosition = -1
        eventContainer.addChild(tint)
        activeNodes.append(tint)

        darken.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 5.0),
            SKAction.wait(forDuration: 10.0),
            SKAction.fadeAlpha(to: 0, duration: 5.0)
        ]))

        tint.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 5.0),
            SKAction.wait(forDuration: 10.0),
            SKAction.fadeAlpha(to: 0, duration: 5.0)
        ]))
    }

    // MARK: - Festival

    func buildFestival() {
        let confettiColors: [SKColor] = [
            PushlingPalette.ember, PushlingPalette.moss, PushlingPalette.tide,
            PushlingPalette.gilt, PushlingPalette.dusk, PushlingPalette.bone
        ]

        for i in 0..<12 {
            let piece = SKShapeNode(rectOf: CGSize(width: 1.5, height: 1))
            piece.fillColor = confettiColors[i % confettiColors.count]
            piece.strokeColor = .clear
            piece.alpha = 0

            let startX = CGFloat.random(in: 50...(Self.sceneWidth - 50))
            piece.position = CGPoint(x: startX, y: Self.sceneHeight + 5)
            piece.zPosition = CGFloat(i % 3)
            eventContainer.addChild(piece)
            activeNodes.append(piece)

            let delay = Double.random(in: 0...3.0)
            let fallDuration = Double.random(in: 3.0...8.0)
            let drift = CGFloat.random(in: -40...40)
            let spin = CGFloat.random(in: -6...6)

            piece.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeAlpha(to: 0.8, duration: 0.3),
                SKAction.group([
                    SKAction.moveBy(x: drift,
                                     y: -(Self.sceneHeight + 10),
                                     duration: fallDuration),
                    SKAction.rotate(byAngle: spin, duration: fallDuration),
                    SKAction.sequence([
                        SKAction.wait(forDuration: fallDuration * 0.7),
                        SKAction.fadeAlpha(to: 0,
                                           duration: fallDuration * 0.3)
                    ])
                ])
            ]))
        }
    }

    // MARK: - Fireflies

    func buildFireflies() {
        fireflyNodes.removeAll()

        let count = Int.random(in: 8...15)
        for i in 0..<count {
            let fly = SKShapeNode(circleOfRadius: 0.8)
            fly.fillColor = PushlingPalette.gilt
            fly.strokeColor = .clear
            fly.alpha = 0

            fly.position = CGPoint(
                x: CGFloat.random(in: 50...(Self.sceneWidth - 50)),
                y: CGFloat.random(in: 4...22)
            )
            fly.zPosition = 1
            fly.name = "firefly_\(i)"
            eventContainer.addChild(fly)
            activeNodes.append(fly)
            fireflyNodes.append(fly)

            let delay = Double.random(in: 0...5.0)
            fly.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeAlpha(
                    to: CGFloat.random(in: 0.3...0.7),
                    duration: 1.0
                )
            ]))

            // Trail child node — moves with firefly, pulses inversely
            let trail = SKShapeNode(circleOfRadius: 0.4)
            trail.fillColor = PushlingPalette.withAlpha(
                PushlingPalette.gilt, alpha: 0.2
            )
            trail.strokeColor = .clear
            trail.position = CGPoint(x: 0, y: -1)
            trail.name = "firefly_trail_\(i)"
            trail.alpha = 0
            fly.addChild(trail)

            // Inverse pulse: offset from main firefly glow
            trail.run(SKAction.sequence([
                SKAction.wait(forDuration: delay + 0.5),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.4, duration: 1.5),
                    SKAction.fadeAlpha(to: 0.1, duration: 1.5)
                ]))
            ]))
        }
    }

    // MARK: - Rainbow

    func buildRainbow() {
        let rainbowColors: [SKColor] = [
            PushlingPalette.ember, PushlingPalette.gilt, PushlingPalette.moss,
            PushlingPalette.tide, PushlingPalette.dusk
        ]

        let centerX = Self.sceneWidth * 0.5
        let baseY: CGFloat = -15
        let baseRadius: CGFloat = 35

        for (i, color) in rainbowColors.enumerated() {
            let radius = baseRadius + CGFloat(i) * 2.5
            let arcPath = CGMutablePath()

            arcPath.addArc(
                center: CGPoint(x: centerX, y: baseY),
                radius: radius,
                startAngle: CGFloat.pi * 0.15,
                endAngle: CGFloat.pi * 0.85,
                clockwise: false
            )

            let arc = SKShapeNode(path: arcPath)
            arc.strokeColor = PushlingPalette.withAlpha(color, alpha: 0.12)
            arc.lineWidth = 1.5
            arc.fillColor = .clear
            arc.alpha = 0
            arc.zPosition = CGFloat(i)
            eventContainer.addChild(arc)
            activeNodes.append(arc)

            let delay = Double(i) * 0.3
            arc.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.fadeAlpha(to: 1.0, duration: 3.0),
                SKAction.wait(forDuration: 12.0 - delay),
                SKAction.fadeAlpha(to: 0, duration: 4.0)
            ]))
        }
    }
}
