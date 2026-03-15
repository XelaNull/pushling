// ActionHandlers.swift — pushling_move, pushling_express, pushling_speak, pushling_perform
// Extension on CommandRouter for Claude's motor actions.
// Dispatches to BehaviorStack (AI-directed layer), SpeechCoordinator,
// CatBehaviors, TaughtBehaviorEngine, and ExpressionMapping.

import Foundation
import CoreGraphics
import QuartzCore

// MARK: - Move Handler

extension CommandRouter {

    func handleMove(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        guard let stack = gc.scene.behaviorStack else {
            return .failure(error: "Behavior stack not available.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "stop"
        let currentX = gc.scene.creatureNode?.position.x ?? 542.5
        let currentFacing = gc.scene.creatureNode?.facing ?? .right
        let stageSpeed = gc.creatureStage.baseWalkSpeed

        var output = LayerOutput()
        var estimatedDuration: TimeInterval = 1.0
        var commandType: AICommandType = .walk

        switch action {
        case "goto":
            let targetX = req.params["x"] as? CGFloat
                ?? CGFloat(req.params["x"] as? Int ?? Int(currentX))
            let clampedX = clamp(targetX,
                                  min: SceneConstants.minX,
                                  max: SceneConstants.maxX)
            let distance = abs(clampedX - currentX)
            let speed = req.params["speed"] as? CGFloat ?? stageSpeed

            output.positionX = clampedX
            output.walkSpeed = speed
            output.facing = clampedX > currentX ? .right : .left
            estimatedDuration = speed > 0 ? Double(distance / speed) : 1.0
            if let z = req.params["z"] as? CGFloat {
                output.positionZ = clamp(z, min: 0.0, max: 1.0)
            }

        case "walk":
            let direction = req.params["direction"] as? String ?? "right"
            let speed = req.params["speed"] as? CGFloat ?? stageSpeed
            let facing: Direction = direction == "left" ? .left : .right

            let duration = req.params["duration"] as? Double ?? 3.0
            let targetX = facing == .right
                ? min(currentX + speed * CGFloat(duration), SceneConstants.maxX)
                : max(currentX - speed * CGFloat(duration), SceneConstants.minX)

            output.positionX = targetX
            output.walkSpeed = speed
            output.facing = facing
            estimatedDuration = duration
            if let z = req.params["z"] as? CGFloat {
                output.positionZ = clamp(z, min: 0.0, max: 1.0)
            }

        case "stop":
            output.positionX = currentX
            output.walkSpeed = 0
            commandType = .idle
            estimatedDuration = -1

        case "jump":
            let velocity = req.params["velocity"] as? CGFloat ?? 4.0
            stack.startJump(initialVelocity: velocity)
            return .success([
                "accepted": true,
                "action": "jump",
                "position_x": Int(currentX),
                "facing": currentFacing.rawValue
            ])

        case "turn":
            let newFacing: Direction = currentFacing == .right ? .left : .right
            output.facing = newFacing
            output.positionX = currentX
            output.walkSpeed = 0
            commandType = .look
            estimatedDuration = 0.5

        case "retreat":
            let speed = stageSpeed * 0.4
            let away: Direction = currentFacing.flipped
            let targetX = away == .right
                ? min(currentX + speed * 2.0, SceneConstants.maxX)
                : max(currentX - speed * 2.0, SceneConstants.minX)

            output.positionX = targetX
            output.walkSpeed = speed
            output.facing = currentFacing
            estimatedDuration = 2.0

        case "pace":
            let range = req.params["range"] as? CGFloat ?? 100
            let speed = req.params["speed"] as? CGFloat ?? stageSpeed

            let leftX = max(currentX - range / 2, SceneConstants.minX)
            let rightX = min(currentX + range / 2, SceneConstants.maxX)

            var out1 = LayerOutput()
            out1.positionX = rightX
            out1.walkSpeed = speed
            out1.facing = .right
            let dur1 = Double(abs(rightX - currentX) / speed)

            var out2 = LayerOutput()
            out2.positionX = leftX
            out2.walkSpeed = speed
            out2.facing = .left
            let dur2 = Double(abs(rightX - leftX) / speed)

            let cmd1 = AICommand(
                id: UUID().uuidString, type: .walk, output: out1,
                holdDuration: dur1,
                enqueuedAt: CACurrentMediaTime()
            )
            let cmd2 = AICommand(
                id: UUID().uuidString, type: .walk, output: out2,
                holdDuration: dur2,
                enqueuedAt: CACurrentMediaTime()
            )
            stack.enqueueAICommand(cmd1)
            stack.enqueueAICommand(cmd2)

            return .success([
                "accepted": true,
                "action": "pace",
                "range": Int(range),
                "estimated_duration_ms": Int((dur1 + dur2) * 1000)
            ])

        case "approach_edge":
            let edge = req.params["edge"] as? String ?? "right"
            let margin: CGFloat = 20
            let targetX = edge == "left"
                ? SceneConstants.minX + margin
                : SceneConstants.maxX - margin

            output.positionX = targetX
            output.walkSpeed = stageSpeed
            output.facing = edge == "left" ? .left : .right
            estimatedDuration = Double(abs(targetX - currentX) / stageSpeed)

        case "center":
            let centerX = SceneConstants.sceneWidth / 2
            output.positionX = centerX
            output.walkSpeed = stageSpeed
            output.facing = centerX > currentX ? .right : .left
            estimatedDuration = Double(abs(centerX - currentX) / stageSpeed)

        case "follow_cursor":
            return .success([
                "accepted": false,
                "error": "follow_cursor is handled by the autonomous layer. "
                    + "Use 'goto' with an x position instead."
            ])

        default:
            return .failure(
                error: "Unknown move action '\(action)'.",
                code: "UNKNOWN_ACTION"
            )
        }

        let command = AICommand(
            id: UUID().uuidString,
            type: commandType,
            output: output,
            holdDuration: estimatedDuration,
            enqueuedAt: CACurrentMediaTime()
        )
        stack.enqueueAICommand(command)

        var successData: [String: Any] = [
            "accepted": true,
            "action": action,
            "position_x": Int(output.positionX ?? currentX),
            "facing": (output.facing ?? currentFacing).rawValue,
            "estimated_duration_ms": estimatedDuration > 0
                ? Int(estimatedDuration * 1000) : -1
        ]
        if let z = output.positionZ {
            successData["position_z"] = z
        }
        return .success(successData)
    }
}

// MARK: - Express Handler

extension CommandRouter {

    func handleExpress(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        guard let stack = gc.scene.behaviorStack else {
            return .failure(error: "Behavior stack not available.",
                            code: "NOT_READY")
        }

        let expression = req.action ?? "neutral"
        let intensity = req.params["intensity"] as? Double ?? 0.7
        let duration = req.params["duration"] as? Double ?? 3.0

        let output = ExpressionMapping.layerOutput(
            for: expression, intensity: intensity
        )

        let command = AICommand(
            id: UUID().uuidString,
            type: .express,
            output: output,
            holdDuration: duration,
            enqueuedAt: CACurrentMediaTime()
        )
        stack.enqueueAICommand(command)

        journalLog(gc, type: "ai_express",
                   summary: "Expressed \(expression) at \(Int(intensity * 100))% intensity")

        return .success([
            "expression": expression,
            "intensity": intensity,
            "duration_s": duration,
            "description": ExpressionMapping.description(for: expression)
        ])
    }
}

// MARK: - Speak Handler

extension CommandRouter {

    func handleSpeak(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        guard let text = req.params["text"] as? String, !text.isEmpty else {
            return .failure(error: "Missing 'text' parameter.", code: "INVALID_PARAMS")
        }

        let styleStr = req.action ?? "say"
        guard let style = SpeechStyle(rawValue: styleStr) else {
            let valid = SpeechStyle.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown speech style '\(styleStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        let request = SpeechRequest(
            text: text,
            style: style,
            source: .ai
        )

        let response = gc.speechCoordinator.speak(request)

        if !response.ok {
            return .failure(
                error: response.errorMessage ?? "Speech failed.",
                code: "SPEECH_GATED"
            )
        }

        let journalType = response.loggedAsFailedSpeech ? "failed_speech" : "ai_speech"
        journalLog(gc, type: journalType,
                   summary: "[\(styleStr)] \(response.spoken)")

        var data: [String: Any] = [
            "spoken": response.spoken,
            "intended": response.intended,
            "filtered": response.filtered,
            "style": styleStr,
            "stage": "\(gc.creatureStage)"
        ]

        if response.filtered {
            data["content_loss_percent"] = response.contentLossPercent
        }

        if response.loggedAsFailedSpeech {
            data["logged_as_failed_speech"] = true
            data["note"] = "Your voice couldn't form all the words yet. "
                + "The attempt was remembered — you'll try again as you grow."
        }

        return .success(data)
    }
}

// MARK: - Perform Handler

extension CommandRouter {

    func handlePerform(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        guard let stack = gc.scene.behaviorStack else {
            return .failure(error: "Behavior stack not available.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "wave"
        let variant = req.params["variant"] as? String ?? "default"

        // Handle sequence separately
        if action == "sequence" {
            return handlePerformSequence(req, gc: gc, stack: stack)
        }

        // Check for taught behavior first
        let db = gc.stateCoordinator.database
        if let taughtRows = try? db.query(
            """
            SELECT data FROM journal
            WHERE type = 'teach' AND summary LIKE ?
            ORDER BY timestamp DESC LIMIT 1
            """,
            arguments: ["%\(action)%"]
        ), let dataStr = taughtRows.first?["data"] as? String,
           let jsonData = dataStr.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            let result = ChoreographyParser.parse(json)
            switch result {
            case .success(let definition):
                if definition.stageMin > gc.creatureStage {
                    return .failure(
                        error: "'\(action)' requires \(definition.stageMin)+ stage. "
                            + "Currently at \(gc.creatureStage).",
                        code: "STAGE_GATED"
                    )
                }
                let mastery = gc.masteryTracker.masteryLevel(for: action)
                gc.taughtBehaviorEngine.begin(
                    definition: definition,
                    mastery: mastery,
                    personality: gc.personality.toSnapshot(),
                    currentTime: CACurrentMediaTime()
                )
                journalLog(gc, type: "ai_perform",
                           summary: "Performed taught trick: \(action)")
                return .success([
                    "accepted": true,
                    "behavior": action,
                    "source": "taught",
                    "mastery": mastery.displayName,
                    "estimated_duration_ms": Int(definition.durationSeconds * 1000)
                ])
            case .failure:
                break
            }
        }

        // Check built-in cat behaviors
        if let catBehavior = CatBehaviors.named(action) {
            if catBehavior.minimumStage > gc.creatureStage {
                return .failure(
                    error: "'\(action)' requires \(catBehavior.minimumStage)+ stage. "
                        + "Currently at \(gc.creatureStage). Available behaviors: "
                        + CatBehaviors.available(at: gc.creatureStage)
                            .map(\.name).joined(separator: ", "),
                    code: "STAGE_GATED"
                )
            }
            if let creature = gc.scene.creatureNode {
                let duration = catBehavior.perform(creature)
                journalLog(gc, type: "ai_perform",
                           summary: "Performed \(action)")
                return .success([
                    "accepted": true,
                    "behavior": action,
                    "source": "built_in",
                    "variant": variant,
                    "estimated_duration_ms": Int(duration * 1000)
                ])
            }
        }

        // Map common perform actions to AI commands
        let mapped = mapPerformToAICommand(action, variant: variant,
                                            stage: gc.creatureStage)
        if let (output, duration) = mapped {
            let command = AICommand(
                id: UUID().uuidString,
                type: .perform,
                output: output,
                holdDuration: duration,
                enqueuedAt: CACurrentMediaTime()
            )
            stack.enqueueAICommand(command)
            journalLog(gc, type: "ai_perform",
                       summary: "Performed \(action)")
            return .success([
                "accepted": true,
                "behavior": action,
                "source": "mapped",
                "variant": variant,
                "estimated_duration_ms": Int(duration * 1000)
            ])
        }

        return .failure(
            error: "Unknown behavior '\(action)'. Built-in: "
                + CatBehaviors.all.map(\.name).joined(separator: ", ")
                + ". Or teach a new trick with pushling_teach.",
            code: "UNKNOWN_BEHAVIOR"
        )
    }

    private func handlePerformSequence(
        _ req: IPCRequest,
        gc: GameCoordinator,
        stack: BehaviorStack
    ) -> IPCResult {
        guard let seq = req.params["sequence"] as? [[String: Any]], !seq.isEmpty else {
            return .failure(
                error: "Sequence requires a 'sequence' array of steps, each with "
                    + "'action' and optional 'duration_s', 'params'.",
                code: "INVALID_PARAMS"
            )
        }

        let label = req.params["label"] as? String ?? "unnamed"
        var totalDuration: TimeInterval = 0

        for step in seq {
            guard let stepAction = step["action"] as? String else { continue }
            let stepDuration = step["duration_s"] as? Double ?? 1.0

            if let (output, _) = mapPerformToAICommand(
                stepAction, variant: "default", stage: gc.creatureStage
            ) {
                let command = AICommand(
                    id: UUID().uuidString,
                    type: .perform,
                    output: output,
                    holdDuration: stepDuration,
                    enqueuedAt: CACurrentMediaTime()
                )
                stack.enqueueAICommand(command)
                totalDuration += stepDuration
            }
        }

        journalLog(gc, type: "ai_perform",
                   summary: "Performed sequence '\(label)' (\(seq.count) steps)")

        return .success([
            "accepted": true,
            "steps": seq.count,
            "label": label,
            "estimated_duration_ms": Int(totalDuration * 1000)
        ])
    }

    /// Maps a perform action name to a LayerOutput and duration.
    /// Delegates to PerformActionMapping for the actual data.
    private func mapPerformToAICommand(
        _ action: String,
        variant: String,
        stage: GrowthStage
    ) -> (LayerOutput, TimeInterval)? {
        PerformActionMapping.map(action, variant: variant, stage: stage)
    }
}
