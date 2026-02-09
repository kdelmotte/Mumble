// ShortcutBinding.swift
// Mumble
//
// Represents a configurable keyboard shortcut — either modifier-only (e.g. Fn)
// or a modifier+key combo (e.g. ⌘D). Persisted via UserDefaults as JSON.

import Foundation
import AppKit

// MARK: - ShortcutBinding

struct ShortcutBinding: Codable, Equatable {

    /// Raw value of `NSEvent.ModifierFlags` stored as `UInt` for Codable conformance.
    var modifierFlagsRaw: UInt

    /// Virtual key code, or `nil` for modifier-only shortcuts (e.g. Fn).
    var keyCode: UInt16?

    // MARK: - Computed Properties

    /// The modifier flags reconstituted from their raw storage.
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
    }

    /// Human-readable representation of the shortcut (e.g. "Fn", "⌘⇧D").
    var displayString: String {
        var parts: [String] = []

        let flags = modifierFlags
        if flags.contains(.function)  { parts.append("Fn") }
        if flags.contains(.control)   { parts.append("⌃") }
        if flags.contains(.option)    { parts.append("⌥") }
        if flags.contains(.shift)     { parts.append("⇧") }
        if flags.contains(.command)   { parts.append("⌘") }

        if let keyCode {
            parts.append(Self.stringForKeyCode(keyCode))
        }

        return parts.isEmpty ? "None" : parts.joined()
    }

    // MARK: - Factory

    /// The default shortcut: solo Fn key press.
    static let defaultFnKey = ShortcutBinding(
        modifierFlagsRaw: NSEvent.ModifierFlags.function.rawValue,
        keyCode: nil
    )

    // MARK: - Persistence

    private static let userDefaultsKey = "com.mumble.shortcutBinding"

    /// Loads the persisted shortcut, falling back to the default Fn key.
    static func load() -> ShortcutBinding {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let binding = try? JSONDecoder().decode(ShortcutBinding.self, from: data)
        else {
            return .defaultFnKey
        }
        return binding
    }

    /// Persists this shortcut to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: ShortcutBinding.userDefaultsKey)
        }
    }

    /// Removes the persisted shortcut, reverting to the default Fn key on next load.
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Key Code to String

    /// Maps a virtual key code to a human-readable character or name.
    private static func stringForKeyCode(_ keyCode: UInt16) -> String {
        // Common key codes on macOS virtual keyboards.
        switch Int(keyCode) {
        case 0:   return "A"
        case 1:   return "S"
        case 2:   return "D"
        case 3:   return "F"
        case 4:   return "H"
        case 5:   return "G"
        case 6:   return "Z"
        case 7:   return "X"
        case 8:   return "C"
        case 9:   return "V"
        case 11:  return "B"
        case 12:  return "Q"
        case 13:  return "W"
        case 14:  return "E"
        case 15:  return "R"
        case 16:  return "Y"
        case 17:  return "T"
        case 18:  return "1"
        case 19:  return "2"
        case 20:  return "3"
        case 21:  return "4"
        case 22:  return "6"
        case 23:  return "5"
        case 24:  return "="
        case 25:  return "9"
        case 26:  return "7"
        case 27:  return "-"
        case 28:  return "8"
        case 29:  return "0"
        case 30:  return "]"
        case 31:  return "O"
        case 32:  return "U"
        case 33:  return "["
        case 34:  return "I"
        case 35:  return "P"
        case 36:  return "↩"
        case 37:  return "L"
        case 38:  return "J"
        case 39:  return "'"
        case 40:  return "K"
        case 41:  return ";"
        case 42:  return "\\"
        case 43:  return ","
        case 44:  return "/"
        case 45:  return "N"
        case 46:  return "M"
        case 47:  return "."
        case 48:  return "⇥"
        case 49:  return "Space"
        case 50:  return "`"
        case 51:  return "⌫"
        case 53:  return "⎋"
        default:  return "Key\(keyCode)"
        }
    }
}
