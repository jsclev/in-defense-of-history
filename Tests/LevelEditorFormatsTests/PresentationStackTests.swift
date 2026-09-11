import XCTest
@testable import LevelEditorFormats

final class PresentationStackTests: XCTestCase {
    func testNewPresentationIsAboveExistingLayersRegardlessOfCategoryOrder() {
        var stack = PresentationStack<String>()
        stack.synchronize(["context"])
        let contextID = stack.entries[0].id

        // The tower category is first in the active-state snapshot, but its
        // newly opened presentation must be last in the rendering order.
        stack.synchronize(["tower", "context"])
        XCTAssertEqual(stack.entries.map(\.content), ["context", "tower"])
        XCTAssertEqual(stack.entries[0].id, contextID)
        XCTAssertNotEqual(stack.entries[1].id, contextID)
    }

    func testRefreshingActiveContentDoesNotRecreateOrRaiseExistingLayers() {
        var stack = PresentationStack<String>()
        stack.synchronize(["tower", "context"])
        let ids = stack.entries.map(\.id)

        stack.synchronize(["context", "tower", "tower"])
        XCTAssertEqual(stack.entries.map(\.content), ["tower", "context"])
        XCTAssertEqual(stack.entries.map(\.id), ids)
    }

    func testDismissingTopPresentationRevealsExistingLayer() {
        var stack = PresentationStack<String>()
        stack.synchronize(["context"])
        let contextID = stack.entries[0].id
        stack.synchronize(["context", "tower"])
        stack.synchronize(["context"])

        XCTAssertEqual(stack.entries.map(\.content), ["context"])
        XCTAssertEqual(stack.entries[0].id, contextID)
    }

    func testClosingAndReopeningCreatesFreshLayerAndViewIdentity() {
        var stack = PresentationStack<String>()
        stack.synchronize(["tower"])
        let firstID = stack.entries[0].id
        stack.synchronize([])
        XCTAssertTrue(stack.entries.isEmpty)

        stack.synchronize(["tower"])
        XCTAssertEqual(stack.entries.count, 1)
        XCTAssertNotEqual(stack.entries[0].id, firstID)
    }

    func testReplacingMenuWithPlacementRemovesOldLayer() {
        var stack = PresentationStack<String>()
        stack.synchronize(["upgrade:1", "flag:1"])
        let flagID = stack.entries[1].id
        stack.synchronize(["placement:1", "flag:1"])

        XCTAssertEqual(stack.entries.map(\.content), ["flag:1", "placement:1"])
        XCTAssertEqual(stack.entries[0].id, flagID)
        stack.synchronize([])
        XCTAssertTrue(stack.entries.isEmpty)
    }

    func testLeavingLevelRemovesEveryPresentation() {
        var stack = PresentationStack<String>()
        stack.synchronize(["tower", "context", "flag"])
        stack.removeAll()
        XCTAssertTrue(stack.entries.isEmpty)
    }
}
