import XCTest
@testable import Mumble

final class ShortcutBindingTests: XCTestCase {

    // MARK: - Default Factory

    func testDefaultFnKey_hasCorrectModifierFlags() {
        let binding = ShortcutBinding.defaultFnKey
        XCTAssertTrue(binding.modifierFlags.contains(.function))
    }

    func testDefaultFnKey_hasNoKeyCode() {
        let binding = ShortcutBinding.defaultFnKey
        XCTAssertNil(binding.keyCode)
    }

    // MARK: - Display String

    func testDisplayString_fnOnly() {
        let binding = ShortcutBinding.defaultFnKey
        XCTAssertEqual(binding.displayString, "Fn")
    }

    func testDisplayString_commandKey() {
        let binding = ShortcutBinding(
            modifierFlagsRaw: NSEvent.ModifierFlags.command.rawValue,
            keyCode: 2 // D key
        )
        XCTAssertEqual(binding.displayString, "\u{2318}D")
    }

    func testDisplayString_commandShiftKey() {
        let binding = ShortcutBinding(
            modifierFlagsRaw: NSEvent.ModifierFlags([.command, .shift]).rawValue,
            keyCode: 2 // D key
        )
        XCTAssertEqual(binding.displayString, "\u{21E7}\u{2318}D")
    }

    func testDisplayString_noModifiersNoKey_returnsNone() {
        let binding = ShortcutBinding(modifierFlagsRaw: 0, keyCode: nil)
        XCTAssertEqual(binding.displayString, "None")
    }

    // MARK: - Equatable

    func testEquatable_identicalBindingsAreEqual() {
        let a = ShortcutBinding.defaultFnKey
        let b = ShortcutBinding.defaultFnKey
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentBindingsAreNotEqual() {
        let a = ShortcutBinding.defaultFnKey
        let b = ShortcutBinding(
            modifierFlagsRaw: NSEvent.ModifierFlags.command.rawValue,
            keyCode: 2
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip_modifierOnly() throws {
        let original = ShortcutBinding.defaultFnKey
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutBinding.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testCodableRoundTrip_modifierPlusKey() throws {
        let original = ShortcutBinding(
            modifierFlagsRaw: NSEvent.ModifierFlags([.command, .option]).rawValue,
            keyCode: 49 // Space
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutBinding.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Modifier Flags Reconstruction

    func testModifierFlags_reconstructedFromRaw() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let binding = ShortcutBinding(modifierFlagsRaw: flags.rawValue, keyCode: nil)
        XCTAssertTrue(binding.modifierFlags.contains(.command))
        XCTAssertTrue(binding.modifierFlags.contains(.shift))
        XCTAssertFalse(binding.modifierFlags.contains(.option))
    }
}
