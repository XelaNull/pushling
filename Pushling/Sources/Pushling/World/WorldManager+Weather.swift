// WorldManager+Weather.swift — Weather restart-persistence (WO-14)
// Weather state and its last-changed timestamp persist to SQLite; on
// daemon restart, WeatherSystem.restoreState(weather:changedAt:)
// reconstructs the correct remaining duration from elapsed wall-clock
// time rather than resetting the clock. See docs/SYSTEMS/weather.md
// ("The State Machine" §, lines 59-63) for the canonical contract.
//
// Extracted from WorldManager.swift to keep that file under the
// 500-line subsystem limit (per CLAUDE.md code-quality table).

import Foundation

extension WorldManager {

    /// Restore weather state from the `world` table.
    /// Called once from `setup()`, after the weather renderers/layers are
    /// wired but before the state machine begins its normal per-frame
    /// cadence — mirrors `loadObjectsFromDB()`/`loadCompanionFromDB()`.
    func restoreWeatherFromDB() {
        guard let db = database else { return }
        guard let rows = try? db.query(
            "SELECT weather, weather_changed_at FROM world WHERE id = 1"
        ), let row = rows.first else { return }

        guard let weather = row["weather"] as? String else { return }

        var changedAt: Date?
        if let changedAtStr = row["weather_changed_at"] as? String {
            changedAt = ISO8601DateFormatter().date(from: changedAtStr)
        }

        weatherSystem.restoreState(weather: weather, changedAt: changedAt)
        NSLog("[Pushling/World] Weather restored from DB: %@ (changed_at: %@)",
              weather, changedAt.map { "\($0)" } ?? "unknown")
    }

    /// Persist the current weather state and its change timestamp to the
    /// `world` table. Called from `update()`'s periodic maintenance block
    /// whenever `weatherSystem.currentState` differs from the last-synced
    /// value — suppressed in workbench mode, matching the companion/object
    /// persistence pattern in `WorldManager+Objects.swift` (the workbench
    /// must never write to the live creature's state.db).
    func persistWeatherChange(_ state: WeatherState) {
        guard let db = database, !WorkbenchMode.isActive else { return }
        let nowStr = ISO8601DateFormatter().string(from: Date())
        db.performWriteAsync({
            try db.execute(
                "UPDATE world SET weather = ?, weather_changed_at = ? WHERE id = 1",
                arguments: [state.rawValue, nowStr]
            )
        })
    }
}
