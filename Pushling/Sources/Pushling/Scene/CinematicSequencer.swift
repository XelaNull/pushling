// CinematicSequencer.swift — Phase-driven orchestrator for cinematic events
// Coordinates camera zoom/pan, touch suppression, behavior freeze, and fog
// during evolution ceremonies and other dramatic moments.
// The sequencer drives camera state from outside — it calls methods on
// CameraController, not the other way around.

import Foundation
import CoreGraphics

final class CinematicSequencer {

    // MARK: - Phase Definitions

    /// A single phase in a cinematic sequence.
    enum Phase {
        /// Pan camera to center on the creature.
        case panToCreature(duration: TimeInterval)
        /// Zoom to a target level with easeInOut.
        case zoomTo(target: CGFloat, duration: TimeInterval)
        /// Hold at current zoom with subtle micro-oscillation.
        case hold(duration: TimeInterval)
        /// Zoom release back to a target level with easeOut.
        case zoomRelease(target: CGFloat, duration: TimeInterval)
        /// Execute a closure immediately and advance.
        case callback(() -> Void)
        /// Wait a fixed duration (for sequencing gaps).
        case wait(duration: TimeInterval)
    }

    /// A complete cinematic sequence: ordered phases plus control flags.
    struct Sequence {
        let phases: [Phase]
        /// Whether touch input is suppressed during this sequence.
        let suppressTouch: Bool
        /// Whether the autonomous behavior layer is frozen.
        let freezeBehavior: Bool
        /// Whether creature counter-scaling is disabled (let creature
        /// fill the frame during cinematic zoom).
        let disableCounterScaling: Bool
        /// Called when the entire sequence completes.
        var onComplete: (() -> Void)?
    }

    // MARK: - State

    /// Whether a cinematic sequence is currently running.
    private(set) var isActive: Bool = false

    /// The current sequence being executed.
    private var currentSequence: Sequence?

    /// Index of the current phase within the sequence.
    private var currentPhaseIndex: Int = 0

    /// Elapsed time within the current phase.
    private var phaseElapsed: TimeInterval = 0

    /// Zoom level captured at the start of a zoom phase.
    private var startZoom: CGFloat = 1.0

    /// Pan offset captured at the start of a pan phase.
    private var startPanOffset: CGFloat = 0

    /// Camera controller driven by this sequencer.
    weak var cameraController: CameraController?

    // MARK: - Micro-Oscillation Constants

    /// Amplitude of the subtle zoom oscillation during hold phases.
    private static let holdOscillationAmplitude: CGFloat = 0.02

    /// Period of the hold oscillation in seconds.
    private static let holdOscillationPeriod: TimeInterval = 3.0

    /// Zoom level captured at hold start (for oscillation baseline).
    private var holdBaseZoom: CGFloat = 1.0

    // MARK: - Lifecycle

    /// Begin executing a cinematic sequence.
    /// If a sequence is already active, it is cancelled first.
    func begin(_ sequence: Sequence) {
        if isActive {
            cancel()
        }

        currentSequence = sequence
        currentPhaseIndex = 0
        phaseElapsed = 0
        isActive = true

        // Capture initial camera state
        startZoom = cameraController?.zoomLevel ?? 1.0
        startPanOffset = cameraController?.panOffset ?? 0

        NSLog("[Pushling/Cinematic] Beginning sequence with %d phases",
              sequence.phases.count)

        // Start the first phase
        beginCurrentPhase()
    }

    /// Per-frame update. Advances the current phase and transitions
    /// to the next when complete.
    func update(deltaTime: TimeInterval) {
        guard isActive, let sequence = currentSequence else { return }
        guard currentPhaseIndex < sequence.phases.count else {
            finishSequence()
            return
        }

        let phase = sequence.phases[currentPhaseIndex]
        phaseElapsed += deltaTime

        switch phase {
        case .panToCreature(let duration):
            updatePanToCreature(duration: duration)
            if phaseElapsed >= duration { advancePhase() }

        case .zoomTo(let target, let duration):
            updateZoomTo(target: target, duration: duration)
            if phaseElapsed >= duration { advancePhase() }

        case .hold(let duration):
            updateHold()
            if phaseElapsed >= duration { advancePhase() }

        case .zoomRelease(let target, let duration):
            updateZoomRelease(target: target, duration: duration)
            if phaseElapsed >= duration { advancePhase() }

        case .callback:
            // Callbacks execute in beginCurrentPhase and auto-advance
            break

        case .wait(let duration):
            if phaseElapsed >= duration { advancePhase() }
        }
    }

    /// Cancel the active sequence immediately (triple-tap escape hatch).
    /// Clears cinematic camera state so normal controls resume.
    func cancel() {
        guard isActive else { return }

        NSLog("[Pushling/Cinematic] Sequence cancelled")

        cameraController?.clearCinematicState()
        let completion = currentSequence?.onComplete
        currentSequence = nil
        currentPhaseIndex = 0
        phaseElapsed = 0
        isActive = false

        completion?()
    }

    // MARK: - Phase Execution

    /// Initialize state for the current phase.
    private func beginCurrentPhase() {
        guard let sequence = currentSequence,
              currentPhaseIndex < sequence.phases.count else {
            finishSequence()
            return
        }

        let phase = sequence.phases[currentPhaseIndex]

        switch phase {
        case .panToCreature:
            // Capture current pan offset as interpolation start
            startPanOffset = cameraController?.panOffset ?? 0

        case .zoomTo:
            // Capture current zoom as interpolation start
            startZoom = cameraController?.cinematicZoom
                ?? cameraController?.zoomLevel ?? 1.0

        case .hold:
            // Capture current zoom as the oscillation baseline
            holdBaseZoom = cameraController?.cinematicZoom
                ?? cameraController?.zoomLevel ?? 1.0

        case .zoomRelease:
            // Capture current zoom as interpolation start
            startZoom = cameraController?.cinematicZoom
                ?? cameraController?.zoomLevel ?? 1.0

        case .callback(let action):
            // Execute immediately and advance to next phase
            action()
            advancePhase()

        case .wait:
            break
        }
    }

    /// Advance to the next phase in the sequence.
    private func advancePhase() {
        currentPhaseIndex += 1
        phaseElapsed = 0

        guard let sequence = currentSequence,
              currentPhaseIndex < sequence.phases.count else {
            finishSequence()
            return
        }

        beginCurrentPhase()
    }

    /// Complete the sequence and clean up.
    private func finishSequence() {
        guard isActive else { return }

        NSLog("[Pushling/Cinematic] Sequence complete")

        cameraController?.clearCinematicState()
        let completion = currentSequence?.onComplete
        isActive = false
        currentSequence = nil
        currentPhaseIndex = 0
        phaseElapsed = 0

        completion?()
    }

    // MARK: - Phase Update Helpers

    /// Interpolate pan offset toward 0 (center on creature) with easeInOut.
    private func updatePanToCreature(duration: TimeInterval) {
        let t = clamp(CGFloat(phaseElapsed / duration), min: 0, max: 1)
        let eased = CGFloat(Easing.easeInOut(Double(t)))
        let currentPan = startPanOffset * (1.0 - eased)
        cameraController?.setCinematicState(zoom: nil, panOffset: currentPan)
    }

    /// Interpolate zoom from current to target with easeInOut.
    private func updateZoomTo(target: CGFloat, duration: TimeInterval) {
        let t = clamp(CGFloat(phaseElapsed / duration), min: 0, max: 1)
        let eased = CGFloat(Easing.easeInOut(Double(t)))
        let currentZoom = lerp(startZoom, target, eased)
        cameraController?.setCinematicState(zoom: currentZoom, panOffset: 0)
    }

    /// Hold at current zoom with subtle micro-oscillation to keep it alive.
    /// Sine wave: +/- 0.02 zoom, 3s period.
    private func updateHold() {
        let oscillation = Self.holdOscillationAmplitude
            * CGFloat(sin(2.0 * .pi * phaseElapsed / Self.holdOscillationPeriod))
        cameraController?.setCinematicState(
            zoom: holdBaseZoom + oscillation, panOffset: 0
        )
    }

    /// Interpolate zoom from current to target with easeOut.
    private func updateZoomRelease(target: CGFloat, duration: TimeInterval) {
        let t = clamp(CGFloat(phaseElapsed / duration), min: 0, max: 1)
        let eased = CGFloat(Easing.easeOut(Double(t)))
        let currentZoom = lerp(startZoom, target, eased)
        cameraController?.setCinematicState(zoom: currentZoom, panOffset: 0)
    }

    // MARK: - Pre-Built Sequences

    /// The cinematic sequence for an evolution ceremony.
    ///
    /// Phases:
    /// 1. Pan to creature (0.3s)
    /// 2. Dramatic zoom in to 2.5x (0.6s)
    /// 3. Callback: trigger the ceremony
    /// 4. Hold during 5s ceremony with micro-oscillation
    /// 5. Zoom release back to 1.0x (1.0s)
    /// 6. Callback: signal completion
    ///
    /// - Parameters:
    ///   - ceremonyDuration: Total ceremony length (typically 5.0s).
    ///   - onStartCeremony: Called at the right moment to trigger
    ///     EvolutionCeremony.begin().
    ///   - onComplete: Called after the full cinematic finishes.
    static func evolutionSequence(
        ceremonyDuration: TimeInterval,
        onStartCeremony: @escaping () -> Void,
        onComplete: (() -> Void)?
    ) -> Sequence {
        Sequence(
            phases: [
                .panToCreature(duration: 0.3),
                .zoomTo(target: 2.5, duration: 0.6),
                .callback(onStartCeremony),
                .hold(duration: ceremonyDuration),
                .zoomRelease(target: 1.0, duration: 1.0),
                .callback({ onComplete?() }),
            ],
            suppressTouch: true,
            freezeBehavior: true,
            disableCounterScaling: true,
            onComplete: nil  // Completion routed through final callback phase
        )
    }

    /// A general-purpose focus sequence: zoom in, hold, zoom out.
    ///
    /// - Parameters:
    ///   - zoomTarget: The zoom level to reach.
    ///   - holdDuration: How long to hold at peak zoom.
    ///   - onComplete: Called after the full cinematic finishes.
    static func focusSequence(
        zoomTarget: CGFloat,
        holdDuration: TimeInterval,
        onComplete: (() -> Void)?
    ) -> Sequence {
        Sequence(
            phases: [
                .panToCreature(duration: 0.3),
                .zoomTo(target: zoomTarget, duration: 0.4),
                .hold(duration: holdDuration),
                .zoomRelease(target: 1.0, duration: 0.6),
            ],
            suppressTouch: true,
            freezeBehavior: false,
            disableCounterScaling: zoomTarget > 1.5,
            onComplete: onComplete
        )
    }

    // MARK: - Query

    /// Whether the current sequence suppresses touch input.
    var suppressesTouch: Bool {
        currentSequence?.suppressTouch ?? false
    }

    /// Whether the current sequence freezes the behavior stack.
    var freezesBehavior: Bool {
        currentSequence?.freezeBehavior ?? false
    }

    /// Whether the current sequence disables creature counter-scaling.
    var disablesCounterScaling: Bool {
        currentSequence?.disableCounterScaling ?? false
    }
}
