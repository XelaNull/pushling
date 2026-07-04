// SpriteFrameLoaderTests.swift — Unit tests for WO-27 sub-part 1's sprite
// frame cache. Exercises the graceful missing-resource path specifically:
// under `swift test`, `Bundle.main` resolves to the raw test executable's
// own bundle, not a build.sh-produced .app — the sprite PNGs are never
// present here (see SpriteFrameLoader.swift's file header), so "resource
// not found" is the NORMAL, expected path this suite pins, not an edge
// case being simulated.

import XCTest
@testable import Pushling

final class SpriteFrameLoaderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SpriteFrameLoader.clearCacheForTesting()
    }

    func testMissingResourceReturnsNilRatherThanCrashing() {
        let texture = SpriteFrameLoader.texture(named: "definitely_not_a_real_sprite_frame")
        XCTAssertNil(texture)
    }

    func testMissingResourceIsConsistentAcrossRepeatedCalls() {
        // Not cached (a miss isn't memoized as a hit) but also not
        // crashing or throwing on a second lookup of the same bad name.
        XCTAssertNil(SpriteFrameLoader.texture(named: "definitely_not_a_real_sprite_frame"))
        XCTAssertNil(SpriteFrameLoader.texture(named: "definitely_not_a_real_sprite_frame"))
    }

    func testTexturesForClipWithAllMissingFramesReturnsEmptyArrayNotACrash() {
        let clip = ClipDefinition(
            frames: ["nonexistent_a", "nonexistent_b"],
            fps: 8, loop: true, anchors: nil
        )
        let textures = SpriteFrameLoader.textures(for: clip)
        XCTAssertTrue(textures.isEmpty)
    }
}
