import AppKit
import XCTest
@testable import Mumble

@MainActor
final class TextInserterTests: XCTestCase {

    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: .init("TextInserterTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
    }

    override func tearDown() {
        pasteboard.clearContents()
        pasteboard = nil
        super.tearDown()
    }

    func testRestorePolicy_restoresPreviousItemsAndFormats() async throws {
        let customType = NSPasteboard.PasteboardType("com.mumble.tests.custom")
        let customData = Data([0x01, 0x02, 0x03])
        let firstItem = NSPasteboardItem()
        firstItem.setString("original", forType: .string)
        firstItem.setData(customData, forType: customType)
        let secondItem = NSPasteboardItem()
        secondItem.setString("second item", forType: .string)
        pasteboard.writeObjects([firstItem, secondItem])

        let inserter = makeInserter()
        inserter.insertText("transcription", clipboardPolicy: .restorePreviousContents)
        try await waitForPasteboardCallbacks()

        let restoredItems = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(restoredItems.count, 2)
        XCTAssertEqual(restoredItems[0].string(forType: .string), "original")
        XCTAssertEqual(restoredItems[0].data(forType: customType), customData)
        XCTAssertEqual(restoredItems[1].string(forType: .string), "second item")
    }

    func testRestorePolicy_restoresOriginallyEmptyClipboard() async throws {
        let inserter = makeInserter()
        inserter.insertText("transcription", clipboardPolicy: .restorePreviousContents)
        try await waitForPasteboardCallbacks()

        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertTrue(pasteboard.pasteboardItems?.isEmpty ?? true)
    }

    func testKeepPolicy_leavesInsertedTextOnClipboard() async throws {
        pasteboard.setString("original", forType: .string)

        let inserter = makeInserter()
        inserter.insertText("final formatted text", clipboardPolicy: .keepInsertedText)
        try await waitForPasteboardCallbacks()

        XCTAssertEqual(pasteboard.string(forType: .string), "final formatted text")
    }

    func testRestorePolicy_doesNotOverwriteNewerClipboardContent() async throws {
        pasteboard.setString("original", forType: .string)

        let inserter = makeInserter(restoreDelay: 0.03)
        inserter.insertText("transcription", clipboardPolicy: .restorePreviousContents)

        pasteboard.clearContents()
        pasteboard.setString("newer user copy", forType: .string)
        try await waitForPasteboardCallbacks(nanoseconds: 80_000_000)

        XCTAssertEqual(pasteboard.string(forType: .string), "newer user copy")
    }

    private func makeInserter(restoreDelay: TimeInterval = 0) -> TextInserter {
        TextInserter(
            pasteboard: pasteboard,
            pasteDelay: 0,
            restoreDelay: restoreDelay,
            pasteAction: {}
        )
    }

    private func waitForPasteboardCallbacks(nanoseconds: UInt64 = 20_000_000) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
