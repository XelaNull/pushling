// SpriteFrameLoader.swift — WO-27 sub-part 1: loads clip frame PNGs into
// cached, nearest-filtered SKTextures.
//
// Reads `Pushling/Resources/sprites/<name>.png` via `Bundle.main` — the
// SAME generic flat resource-copy step `build.sh:206-208` already runs
// for png/jpg/wav/mp3/json (confirmed by reading build.sh: no build.sh
// change needed for this pass; the copy is flat, no subdirectories,
// which is exactly why every sprite filename must be unique on its own).
//
// NOT wired into any render path yet — CreatureNode never calls this
// (sub-part 2's job). This is a standalone, independently-testable cache
// with no callers today besides its own tests.
//
// IMPORTANT for verification: `swift build`/`swift test` run the raw
// executable straight from `.build/`, not a bundled `.app` — `Bundle.main`
// in that context resolves to `.build/{debug,release}/`, which never
// receives build.sh's resource-copy step. Missing-resource handling below
// is therefore not just a defensive nicety, it is the EXPECTED, exercised
// path in every `swift test`/plain `swift build` run until a full
// `build.sh` pass produces a real `.app` bundle — NSLog + skip, never a
// crash, never a partial throw.

import Foundation
import AppKit
import SpriteKit

enum SpriteFrameLoader {

    /// frame name -> loaded texture. Cleared only by process restart —
    /// frame counts are tiny (single-digit-KB PNGs at Touch Bar scale,
    /// confirmed ~3.3KB each for WO-27 sub-part 1's Beast set) so there is
    /// no eviction policy.
    private static var cache: [String: SKTexture] = [:]

    /// Loads (or returns the cached) textures for a clip's frame names, in
    /// order. Every texture has `.filteringMode = .nearest` set — the P1
    /// legibility obligation: SpriteKit's default `.linear` would mush a
    /// nearest-neighbor-upscaled 36x40-native source at Touch Bar scale.
    ///
    /// Missing resources are skipped, never thrown: the returned array may
    /// be shorter than `clip.frames`, or empty, and callers must treat
    /// that as "nothing to play yet," matching `ClipTable.clip(for:stage:)`'s
    /// own "nil = nothing to play yet, not an error" contract.
    static func textures(for clip: ClipDefinition) -> [SKTexture] {
        clip.frames.compactMap { texture(named: $0) }
    }

    /// Loads (or returns the cached) texture for a single frame name.
    /// Returns nil and logs via `NSLog` on any failure (resource not
    /// found, or found but undecodable) — never crashes.
    static func texture(named name: String) -> SKTexture? {
        if let cached = cache[name] {
            return cached
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            NSLog("[SpriteFrameLoader] sprite resource not found in bundle: %@.png", name)
            return nil
        }
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            NSLog("[SpriteFrameLoader] sprite resource found but undecodable: %@.png", name)
            return nil
        }
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    /// Test-only escape hatch to reset the cache between assertions that
    /// care about cache-miss vs. cache-hit behavior. Never called from
    /// production code.
    static func clearCacheForTesting() {
        cache.removeAll()
    }
}
