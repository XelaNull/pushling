// WeatherSystem.swift — Weather state machine and renderer coordination
// P3-T2-04: State machine checked every 5 minutes.
// States: Clear (55%), Cloudy (18%), Rain (12%), Storm (5%), Snow (3%), Fog (7%).
// Transitions are smooth (30-60 second crossfade, never snapping).
//
// WeatherSystem owns the state machine and coordinates all weather renderers.
// Weather state is persisted in SQLite via the world table.

import SpriteKit

// MARK: - Weather State

/// The possible weather states with their transition probabilities.
enum WeatherState: String, CaseIterable {
    case clear  = "clear"
    case cloudy = "cloudy"
    case rain   = "rain"
    case storm  = "storm"
    case snow   = "snow"
    case fog    = "fog"

    /// Base probability of transitioning TO this state.
    var probability: Double {
        switch self {
        case .clear:  return 0.55
        case .cloudy: return 0.18
        case .rain:   return 0.12
        case .storm:  return 0.05
        case .snow:   return 0.03
        case .fog:    return 0.07
        }
    }

    /// Duration range in seconds.
    var durationRange: ClosedRange<TimeInterval> {
        switch self {
        case .clear:  return 300...1800   // 5-30 min
        case .cloudy: return 300...1200   // 5-20 min
        case .rain:   return 300...900    // 5-15 min
        case .storm:  return 180...600    // 3-10 min
        case .snow:   return 300...1200   // 5-20 min
        case .fog:    return 300...1500   // 5-25 min
        }
    }

    /// Which states this state is allowed to transition to.
    /// Prevents jarring transitions (e.g., clear -> storm without cloudy/rain).
    var validTransitions: [WeatherState] {
        switch self {
        case .clear:  return [.clear, .cloudy, .fog]
        case .cloudy: return [.clear, .cloudy, .rain, .snow, .fog]
        case .rain:   return [.clear, .cloudy, .rain, .storm]
        case .storm:  return [.rain, .cloudy]  // Storms die down to rain or clouds
        case .snow:   return [.clear, .cloudy, .snow]
        case .fog:    return [.clear, .cloudy, .fog]
        }
    }

    /// Sky darkening factor for this weather (0.0 = no darkening).
    var skyDarkenFactor: CGFloat {
        switch self {
        case .clear:  return 0.0
        case .cloudy: return 0.1
        case .rain:   return 0.25
        case .storm:  return 0.5
        case .snow:   return 0.05
        case .fog:    return 0.15
        }
    }

    /// Sky darkening color.
    var skyDarkenColor: SKColor {
        switch self {
        case .storm:
            // Near-Void with Dusk undertone
            return PushlingPalette.lerp(
                from: PushlingPalette.void_,
                to: PushlingPalette.dusk,
                t: 0.15
            )
        default:
            return PushlingPalette.ash.withAlphaComponent(0.5)
        }
    }
}

// MARK: - Weather Transition

/// Tracks the smooth crossfade between two weather states.
struct WeatherTransition {
    let from: WeatherState
    let to: WeatherState
    let duration: TimeInterval    // 30-60 seconds
    var elapsed: TimeInterval = 0

    /// Progress of the transition (0.0 = fully 'from', 1.0 = fully 'to').
    var progress: CGFloat {
        return CGFloat(min(1.0, elapsed / duration))
    }

    /// Whether the transition has completed.
    var isComplete: Bool {
        return elapsed >= duration
    }
}

// MARK: - Weather Reaction Delegate

/// Protocol for creature weather reactions.
/// The creature's behavior system implements this to respond to weather changes.
/// This is a STUB — the creature behavior system will connect in Phase 4.
protocol WeatherReactionDelegate: AnyObject {

    /// Called when weather transitions to a new state.
    /// - Parameters:
    ///   - newWeather: The new weather state
    ///   - previousWeather: The state that was active before
    func weatherChanged(to newWeather: WeatherState, from previousWeather: WeatherState)

    /// Called when lightning strikes during a storm.
    /// Creature should react with a startle/flinch.
    func lightningStruck()

    /// Called when thunder rumbles (0.5-2s after lightning).
    /// Creature should flatten ears, show fear.
    func thunderRumbled()

    /// Called when weather clears after rain or storm.
    /// Creature should shake off, investigate puddles.
    func weatherCleared(previousWeather: WeatherState)

    /// Called when fog begins or changes density.
    /// Creature should move cautiously.
    func fogChanged(density: CGFloat)
}

// MARK: - Weather System

/// Manages the weather state machine, transitions, and all weather renderers.
/// Checks for weather changes every 5 minutes. Transitions take 30-60 seconds.
final class WeatherSystem {

    // MARK: - Constants

    /// How often to check for a weather change (seconds).
    private static let checkInterval: TimeInterval = 300  // 5 minutes

    /// Weather transition duration range (seconds).
    private static let transitionDurationRange: ClosedRange<TimeInterval> = 30...60

    /// Scene dimensions.
    static let sceneWidth: CGFloat = 1085
    static let sceneHeight: CGFloat = 30

    // MARK: - Renderers

    let rainRenderer: RainRenderer
    let snowRenderer: SnowRenderer
    let stormSystem: StormSystem
    let fogRenderer: FogRenderer

    // MARK: - State

    /// Current active weather state.
    private(set) var currentState: WeatherState = .clear

    /// Active transition (nil if not transitioning).
    private(set) var activeTransition: WeatherTransition?

    /// Time until next weather check.
    private var timeUntilCheck: TimeInterval

    /// Current weather duration remaining.
    private var weatherDurationRemaining: TimeInterval = 0

    /// Reference to sky system for darkening.
    weak var skySystem: SkySystem?

    /// Delegate for creature reactions.
    weak var reactionDelegate: WeatherReactionDelegate?

    /// Optional MCP override: set to force a weather state.
    var overrideState: WeatherState? {
        didSet {
            if let override = overrideState {
                beginTransition(to: override)
            }
        }
    }

    // MARK: - Init

    init() {
        rainRenderer = RainRenderer()
        snowRenderer = SnowRenderer()
        stormSystem = StormSystem()
        fogRenderer = FogRenderer()

        // Randomize first check time so it doesn't always happen at session start
        timeUntilCheck = TimeInterval.random(in: 30...120)

        // Start with a random duration for initial clear weather
        weatherDurationRemaining = TimeInterval.random(
            in: WeatherState.clear.durationRange
        )
    }

    // MARK: - Scene Integration

    /// Add all weather renderer nodes to the scene.
    /// Call once during scene setup.
    func addToScene(parent: SKNode) {
        rainRenderer.addToScene(parent: parent)
        snowRenderer.addToScene(parent: parent)
        stormSystem.addToScene(parent: parent)
        fogRenderer.addToScene(parent: parent)
    }

    // MARK: - Frame Update

    /// Called every frame from the scene's update loop.
    /// Manages the state machine timer and updates active renderers.
    func update(deltaTime: TimeInterval) {
        // Update weather check timer
        timeUntilCheck -= deltaTime
        weatherDurationRemaining -= deltaTime

        if timeUntilCheck <= 0 {
            timeUntilCheck = Self.checkInterval
            checkForWeatherChange()
        }

        // Update active transition
        if var transition = activeTransition {
            transition.elapsed += deltaTime
            activeTransition = transition

            if transition.isComplete {
                completeTransition()
            } else {
                updateTransitionRenderers(progress: transition.progress)
            }
        }

        // Update active renderers
        updateRenderers(deltaTime: deltaTime)

        // Update sky darkening
        updateSkyDarkening()
    }

    // MARK: - State Machine

    /// Check if weather should change.
    private func checkForWeatherChange() {
        // Don't change if override is active
        guard overrideState == nil else { return }

        // Don't change if currently transitioning
        guard activeTransition == nil else { return }

        // Don't change if current weather hasn't expired
        guard weatherDurationRemaining <= 0 else { return }

        // Pick next weather state
        let nextState = selectNextWeather()
        if nextState != currentState {
            beginTransition(to: nextState)
        } else {
            // Same state — reset duration
            weatherDurationRemaining = TimeInterval.random(
                in: currentState.durationRange
            )
        }
    }

    /// Select the next weather state using weighted random selection.
    /// Only considers valid transitions from the current state.
    private func selectNextWeather() -> WeatherState {
        let valid = currentState.validTransitions
        let totalWeight = valid.reduce(0.0) { $0 + $1.probability }
        var roll = Double.random(in: 0..<totalWeight)

        for state in valid {
            roll -= state.probability
            if roll <= 0 {
                return state
            }
        }

        return .clear  // Fallback
    }

    /// Begin a smooth transition to a new weather state.
    private func beginTransition(to newState: WeatherState) {
        guard activeTransition == nil else { return }

        let duration = TimeInterval.random(in: Self.transitionDurationRange)
        activeTransition = WeatherTransition(
            from: currentState,
            to: newState,
            duration: duration
        )

        // Pre-activate the target renderer so it can fade in
        activateRenderer(for: newState)

        NSLog("[Pushling] Weather transitioning: \(currentState.rawValue) -> \(newState.rawValue) over \(Int(duration))s")
    }

    /// Complete the current transition.
    private func completeTransition() {
        guard let transition = activeTransition else { return }

        let previousState = currentState
        currentState = transition.to
        activeTransition = nil

        // Deactivate the old renderer
        deactivateRenderer(for: previousState)

        // Set full intensity on new renderer
        setRendererIntensity(for: currentState, intensity: 1.0)

        // Set new duration
        weatherDurationRemaining = TimeInterval.random(
            in: currentState.durationRange
        )

        // Notify creature
        reactionDelegate?.weatherChanged(to: currentState, from: previousState)

        // Special notification for clearing weather
        if currentState == .clear && (previousState == .rain || previousState == .storm) {
            reactionDelegate?.weatherCleared(previousWeather: previousState)
        }

        NSLog("[Pushling] Weather now: \(currentState.rawValue) (duration: \(Int(weatherDurationRemaining))s)")
    }

    // MARK: - Renderer Management

    /// Update renderers during a transition (crossfade).
    private func updateTransitionRenderers(progress: CGFloat) {
        guard let transition = activeTransition else { return }

        // Fade out old renderer
        setRendererIntensity(for: transition.from, intensity: 1.0 - progress)

        // Fade in new renderer
        setRendererIntensity(for: transition.to, intensity: progress)
    }

    /// Set the intensity/opacity of a weather renderer.
    private func setRendererIntensity(for state: WeatherState, intensity: CGFloat) {
        switch state {
        case .clear:
            break  // No renderer for clear weather
        case .cloudy:
            break  // Clouds handled by sky darkening only (for now)
        case .rain:
            rainRenderer.intensity = intensity
        case .storm:
            stormSystem.intensity = intensity
            rainRenderer.intensity = intensity  // Storm includes heavy rain
        case .snow:
            snowRenderer.intensity = intensity
        case .fog:
            fogRenderer.intensity = intensity
        }
    }

    /// Activate a renderer (start spawning particles, etc.)
    private func activateRenderer(for state: WeatherState) {
        switch state {
        case .clear, .cloudy: break
        case .rain:   rainRenderer.activate()
        case .storm:  stormSystem.activate(); rainRenderer.activate()
        case .snow:   snowRenderer.activate()
        case .fog:    fogRenderer.activate()
        }
    }

    /// Deactivate a renderer (stop spawning, let existing particles die).
    private func deactivateRenderer(for state: WeatherState) {
        switch state {
        case .clear, .cloudy: break
        case .rain:   rainRenderer.deactivate()
        case .storm:  stormSystem.deactivate(); rainRenderer.deactivate()
        case .snow:   snowRenderer.deactivate()
        case .fog:    fogRenderer.deactivate()
        }
    }

    /// Update all active renderers each frame.
    private func updateRenderers(deltaTime: TimeInterval) {
        // Rain and storm renderers update together (storm uses heavier rain)
        if currentState == .rain || currentState == .storm ||
           activeTransition?.from == .rain || activeTransition?.from == .storm ||
           activeTransition?.to == .rain || activeTransition?.to == .storm {
            rainRenderer.update(deltaTime: deltaTime)
        }

        if currentState == .storm ||
           activeTransition?.from == .storm || activeTransition?.to == .storm {
            stormSystem.update(deltaTime: deltaTime, weatherSystem: self)
        }

        if currentState == .snow ||
           activeTransition?.from == .snow || activeTransition?.to == .snow {
            snowRenderer.update(deltaTime: deltaTime)
        }

        if currentState == .fog ||
           activeTransition?.from == .fog || activeTransition?.to == .fog {
            fogRenderer.update(deltaTime: deltaTime)
        }
    }

    // MARK: - Sky Darkening

    /// Update the sky system's weather darkening based on current weather.
    private func updateSkyDarkening() {
        guard let sky = skySystem else { return }

        let darkenFactor: CGFloat
        let darkenColor: SKColor

        if let transition = activeTransition {
            // Blend darkening during transition
            let fromFactor = transition.from.skyDarkenFactor * (1.0 - transition.progress)
            let toFactor = transition.to.skyDarkenFactor * transition.progress
            darkenFactor = fromFactor + toFactor
            darkenColor = PushlingPalette.lerp(
                from: transition.from.skyDarkenColor,
                to: transition.to.skyDarkenColor,
                t: transition.progress
            )
        } else {
            darkenFactor = currentState.skyDarkenFactor
            darkenColor = currentState.skyDarkenColor
        }

        sky.applyWeatherDarkening(alpha: darkenFactor, color: darkenColor)
    }

    // MARK: - External API

    /// Force a specific weather state (for MCP pushling_world("weather", ...)).
    func forceWeather(_ state: WeatherState, duration: TimeInterval? = nil) {
        overrideState = state
        if let duration = duration {
            weatherDurationRemaining = duration
            // Clear override after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.overrideState = nil
            }
        }
    }

    /// Current weather description for MCP state queries.
    var weatherDescription: [String: Any] {
        var desc: [String: Any] = [
            "state": currentState.rawValue,
            "duration_remaining": Int(weatherDurationRemaining)
        ]
        if let transition = activeTransition {
            desc["transitioning_to"] = transition.to.rawValue
            desc["transition_progress"] = Double(transition.progress)
        }
        return desc
    }

    /// Restore weather state from SQLite (called on daemon restart).
    func restoreState(weather: String, changedAt: Date?) {
        if let state = WeatherState(rawValue: weather) {
            currentState = state
            activateRenderer(for: state)
            setRendererIntensity(for: state, intensity: 1.0)

            // Calculate remaining duration from changedAt
            if let changedAt = changedAt {
                let elapsed = Date().timeIntervalSince(changedAt)
                let maxDuration = state.durationRange.upperBound
                weatherDurationRemaining = max(0, maxDuration - elapsed)
            } else {
                weatherDurationRemaining = TimeInterval.random(
                    in: state.durationRange
                )
            }
        }
    }
}
