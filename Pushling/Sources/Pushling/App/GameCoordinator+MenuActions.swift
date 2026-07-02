// GameCoordinator+MenuActions.swift — P menu button handlers
// Wires Pet/Feed/Play menu buttons to creature reactions.
// Each button triggers an INSTANT visible creature reaction (<100ms).

import Foundation
import SpriteKit
import QuartzCore

// MARK: - Menu Actions

extension GameCoordinator {

    // MARK: - Pet

    /// Tap Pet → hearts float up, creature purrs, contentment rises.
    /// Three rapid taps → slow-blink trust signal.
    func menuPet() {
        let now = CACurrentMediaTime()

        // Hearts burst at creature position
        if let creature = scene.creatureNode {
            let burstOrigin = CGPoint(
                x: creature.position.x,
                y: creature.position.y  // At creature center, hearts rise from there
            )
            TouchParticles.emitHeartBurst(at: burstOrigin, in: scene)
        }

        // Purr reflex — ears flatten, soft eyes
        let purrReflex = ReflexDefinition(
            name: "menu_pet",
            duration: 1.5,
            fadeoutFraction: 0.3,
            output: {
                var o = LayerOutput()
                o.earLeftState = "back"
                o.earRightState = "back"
                o.eyeLeftState = "soft"
                o.eyeRightState = "soft"
                o.tailState = "sway"
                return o
            }()
        )
        scene.behaviorStack?.reflexes.trigger(purrReflex, at: now)

        // Emotional boost
        emotionalState.boostFromInteraction()

        // Track rapid pet taps for slow-blink
        menuPetTapCount += 1
        lastMenuPetTime = now

        if menuPetTapCount >= 3 {
            // Slow-blink trust signal — creature lies down
            let slowBlink = ReflexDefinition(
                name: "slow_blink",
                duration: 3.0,
                fadeoutFraction: 0.2,
                output: {
                    var o = LayerOutput()
                    o.eyeLeftState = "half"
                    o.eyeRightState = "half"
                    o.earLeftState = "flat"
                    o.earRightState = "flat"
                    o.tailState = "wrap"
                    o.bodyState = "loaf"
                    return o
                }()
            )
            scene.behaviorStack?.reflexes.trigger(slowBlink, at: now)
            menuPetTapCount = 0

            // Extra contentment for the trust signal
            emotionalState.boostFromMilestone()
        }

        // Reset tap count after 2 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if CACurrentMediaTime() - self.lastMenuPetTime > 1.5 {
                self.menuPetTapCount = 0
            }
        }

        NSLog("[Pushling/Menu] Pet! (tap #%d, contentment: %.0f)",
              menuPetTapCount, emotionalState.contentment)
    }

    // MARK: - Feed

    /// Tap Feed → creature walks to center, eating animation plays.
    /// Uses the most recent unprocessed commit if available,
    /// otherwise gives a small treat (reduced XP).
    func menuFeed() {
        // Trigger a small satisfaction boost regardless
        emotionalState.boostFromTouch()

        // Spawn a treat that flies in like a meteor from the right
        if let creature = scene.creatureNode {
            // Launch from off-screen right, long slow arc, crash in FRONT of creature
            let launchX = min(creature.position.x + 400, 1085)
            let launchY: CGFloat = 22
            let landX = creature.position.x + 30  // In front of creature, not on it
            let landY: CGFloat = SceneConstants.groundY

            let treat = SKShapeNode(circleOfRadius: 2.0)
            treat.fillColor = PushlingPalette.gilt
            treat.strokeColor = PushlingPalette.ember
            treat.lineWidth = 0.5
            treat.position = CGPoint(x: launchX, y: launchY)
            treat.zPosition = 50
            treat.glowWidth = 2
            scene.addChild(treat)

            // Meteor trail particles during flight (~5s, emit every 0.08s)
            let trailCount = 60
            let emitTrail = SKAction.repeat(SKAction.sequence([
                SKAction.run { [weak treat, weak self] in
                    guard let treat = treat, let scene = self?.scene else { return }
                    let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.2))
                    spark.fillColor = PushlingPalette.ember
                    spark.strokeColor = .clear
                    spark.alpha = 0.8
                    spark.position = CGPoint(
                        x: treat.position.x + CGFloat.random(in: -1...1),
                        y: treat.position.y + CGFloat.random(in: -1...1)
                    )
                    spark.zPosition = 49
                    scene.addChild(spark)
                    spark.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.fadeOut(withDuration: 0.5),
                            SKAction.scale(to: 0.1, duration: 0.5),
                            SKAction.moveBy(x: CGFloat.random(in: 2...6),
                                            y: CGFloat.random(in: -2...2),
                                            duration: 0.5)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                },
                SKAction.wait(forDuration: 0.08)
            ]), count: trailCount)

            // Slow arc path over ~5 seconds
            // Phase 1: cruise across the sky (3.5s, gentle descent)
            let cruiseX = landX + 60
            let cruiseY: CGFloat = 18
            let cruise = SKAction.move(to: CGPoint(x: cruiseX, y: cruiseY), duration: 3.5)
            cruise.timingMode = .easeIn

            // Phase 2: final dive to ground (1.5s, accelerating)
            let dive = SKAction.move(to: CGPoint(x: landX, y: landY), duration: 1.5)
            dive.timingMode = .easeIn

            let flight = SKAction.sequence([cruise, dive])

            // Impact: flash + dust cloud
            let impact = SKAction.sequence([
                SKAction.run { [weak self] in
                    guard let scene = self?.scene else { return }
                    // Impact flash
                    let flash = SKShapeNode(circleOfRadius: 5)
                    flash.fillColor = PushlingPalette.gilt
                    flash.strokeColor = .clear
                    flash.blendMode = .add
                    flash.alpha = 0.6
                    flash.position = CGPoint(x: landX, y: landY + 2)
                    flash.zPosition = 51
                    scene.addChild(flash)
                    flash.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: 3.0, duration: 0.3),
                            SKAction.fadeOut(withDuration: 0.3)
                        ]),
                        SKAction.removeFromParent()
                    ]))
                    // Dust particles
                    for _ in 0..<6 {
                        let dust = SKShapeNode(circleOfRadius: 1.0)
                        dust.fillColor = PushlingPalette.ash
                        dust.strokeColor = .clear
                        dust.alpha = 0.6
                        dust.position = CGPoint(x: landX, y: landY + 1)
                        dust.zPosition = 48
                        scene.addChild(dust)
                        dust.run(SKAction.sequence([
                            SKAction.group([
                                SKAction.moveBy(
                                    x: CGFloat.random(in: -15...15),
                                    y: CGFloat.random(in: 2...8),
                                    duration: 0.6),
                                SKAction.fadeOut(withDuration: 0.6),
                                SKAction.scale(to: 0.3, duration: 0.6)
                            ]),
                            SKAction.removeFromParent()
                        ]))
                    }
                },
                SKAction.group([
                    SKAction.scale(to: 0.3, duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.removeFromParent()
            ])

            // After meteor flight + impact, treat sits on ground glowing.
            // Then creature walks to it and eats it.
            let afterImpact = SKAction.run { [weak self] in
                guard let self = self,
                      let creature = self.scene.creatureNode else { return }
                let now = CACurrentMediaTime()

                // Place a glowing treat on the ground at the crash site
                let morsel = SKShapeNode(circleOfRadius: 2.0)
                morsel.fillColor = PushlingPalette.gilt
                morsel.strokeColor = .clear
                morsel.position = CGPoint(x: landX, y: landY + 2)
                morsel.zPosition = 45
                morsel.glowWidth = 3
                self.scene.addChild(morsel)

                // Gentle pulse while waiting for creature
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.4),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.4)
                ]))
                morsel.run(pulse, withKey: "pulse")

                // Creature notices: ears perk, looks toward treat
                let noticeReflex = ReflexDefinition(
                    name: "notice_treat",
                    duration: 1.5,
                    fadeoutFraction: 0.3,
                    output: {
                        var o = LayerOutput()
                        o.earLeftState = "perk"
                        o.earRightState = "perk"
                        o.eyeLeftState = "wide"
                        o.eyeRightState = "wide"
                        return o
                    }()
                )
                self.scene.behaviorStack?.reflexes.trigger(noticeReflex, at: now)

                // After 1.5s: creature "eats" — morsel shrinks into creature + reward
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self = self,
                          let creature = self.scene.creatureNode else { return }
                    let eatNow = CACurrentMediaTime()

                    // Morsel flies to creature and shrinks
                    morsel.removeAction(forKey: "pulse")
                    let flyToCreature = SKAction.move(
                        to: CGPoint(x: creature.position.x,
                                    y: creature.position.y),
                        duration: 0.3)
                    flyToCreature.timingMode = .easeIn
                    morsel.run(SKAction.sequence([
                        flyToCreature,
                        SKAction.group([
                            SKAction.scale(to: 0.1, duration: 0.15),
                            SKAction.fadeOut(withDuration: 0.15)
                        ]),
                        SKAction.removeFromParent()
                    ]))

                    // Creature eats: mouth open, happy
                    let eatReflex = ReflexDefinition(
                        name: "menu_eat",
                        duration: 1.5,
                        fadeoutFraction: 0.3,
                        output: {
                            var o = LayerOutput()
                            o.earLeftState = "back"
                            o.earRightState = "back"
                            o.eyeLeftState = "soft"
                            o.eyeRightState = "soft"
                            o.mouthState = "open"
                            return o
                        }()
                    )
                    self.scene.behaviorStack?.reflexes.trigger(eatReflex, at: eatNow)

                    // Hearts burst — creature is happy (start at body center)
                    TouchParticles.emitHeartBurst(
                        at: CGPoint(x: creature.position.x,
                                    y: creature.position.y),
                        in: self.scene)

                    // "+XP" floating text
                    let treatXP = Int.random(in: 1...2)
                    self.totalXP += treatXP
                    self.persistXPAndStage()

                    let xpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                    xpLabel.fontSize = 8
                    xpLabel.fontColor = PushlingPalette.gilt
                    xpLabel.text = "+\(treatXP)"
                    xpLabel.position = CGPoint(
                        x: creature.position.x + 10,
                        y: creature.position.y - 2)  // Start at creature center
                    xpLabel.zPosition = 55
                    self.scene.addChild(xpLabel)

                    // Rise slowly so user can read it on the 30pt bar
                    xpLabel.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.moveBy(x: 0, y: 6, duration: 2.0),
                            SKAction.sequence([
                                SKAction.wait(forDuration: 1.2),
                                SKAction.fadeOut(withDuration: 0.8)
                            ])
                        ]),
                        SKAction.removeFromParent()
                    ]))

                    // Emotional boost
                    self.emotionalState.boostFromInteraction()

                    NSLog("[Pushling/Menu] Feed! +%d XP (total: %d, satisfaction: %.0f)",
                          treatXP, self.totalXP, self.emotionalState.satisfaction)
                }
            }

            treat.run(SKAction.sequence([
                SKAction.group([flight, emitTrail]),
                impact,
                afterImpact
            ]))
        }

        NSLog("[Pushling/Menu] Feed! (satisfaction: %.0f, xp: %d)",
              emotionalState.satisfaction, totalXP)
    }

    // MARK: - Play

    /// Tap Play → laser dot spawns, creature chases it autonomously.
    func menuPlay() {
        NSLog("[Pushling/Menu] Play tapped! (laser dot — coming in Day 3-4)")
        // TODO: spawn laser dot, creature chases
        // For now, trigger a playful reflex as a placeholder
        let now = CACurrentMediaTime()
        let playReflex = ReflexDefinition(
            name: "menu_play",
            duration: 2.0,
            fadeoutFraction: 0.3,
            output: {
                var o = LayerOutput()
                o.earLeftState = "perk"
                o.earRightState = "perk"
                o.eyeLeftState = "wide"
                o.eyeRightState = "wide"
                o.tailState = "high"
                return o
            }()
        )
        scene.behaviorStack?.reflexes.trigger(playReflex, at: now)

        // Emit sparkles as placeholder for play
        if let creature = scene.creatureNode {
            TouchParticles.emitMomentRing(
                at: creature.position, in: scene)
        }
    }
}

// MARK: - Pet Tap Tracking (stored state)

private var _menuPetTapCount: Int = 0
private var _lastMenuPetTime: TimeInterval = 0

extension GameCoordinator {
    var menuPetTapCount: Int {
        get { _menuPetTapCount }
        set { _menuPetTapCount = newValue }
    }
    var lastMenuPetTime: TimeInterval {
        get { _lastMenuPetTime }
        set { _lastMenuPetTime = newValue }
    }
}
