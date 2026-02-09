import Foundation
import AppKit
import Carbon.HIToolbox

// MARK: - TextInserter

final class TextInserter {

    /// The delay (in seconds) between setting the pasteboard content and sending the
    /// Cmd+V keystroke. A small delay improves reliability across different target apps.
    private let pasteDelay: TimeInterval = 0.05

    /// The delay (in seconds) before restoring the original pasteboard content after the
    /// paste keystroke has been sent. This gives the target app time to read the pasteboard.
    private let restoreDelay: TimeInterval = 0.15

    // MARK: - Public API

    /// Inserts the given text at the current cursor position in the frontmost application
    /// by temporarily placing it on the system pasteboard and simulating Cmd+V.
    ///
    /// The previous pasteboard content is saved and restored after a brief delay.
    /// This method must be called on the main thread.
    func insertText(_ text: String) {
        assert(Thread.isMainThread, "TextInserter.insertText must be called on the main thread")

        let pasteboard = NSPasteboard.general

        // 1. Save the current pasteboard contents.
        let savedContents = savePasteboardContents(pasteboard)

        // 2. Set the new text onto the pasteboard.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. After a short delay, simulate Cmd+V.
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            guard let self else { return }
            self.simulatePaste()

            // 4. After another delay, restore the previous pasteboard contents.
            DispatchQueue.main.asyncAfter(deadline: .now() + self.restoreDelay) {
                self.restorePasteboardContents(savedContents, to: pasteboard)
            }
        }
    }

    // MARK: - Pasteboard Save / Restore

    /// Captures all items currently on the pasteboard so they can be restored later.
    private func savePasteboardContents(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        var saved: [[NSPasteboard.PasteboardType: Data]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            if !itemData.isEmpty {
                saved.append(itemData)
            }
        }

        return saved
    }

    /// Restores previously saved pasteboard contents.
    private func restorePasteboardContents(
        _ contents: [[NSPasteboard.PasteboardType: Data]],
        to pasteboard: NSPasteboard
    ) {
        guard !contents.isEmpty else { return }

        pasteboard.clearContents()

        var items: [NSPasteboardItem] = []
        for itemData in contents {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            items.append(item)
        }

        pasteboard.writeObjects(items)
    }

    // MARK: - Keyboard Simulation

    /// Simulates a Cmd+V keystroke using CGEvents.
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code 9 = 'V' on a US keyboard layout.
        let keyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            STTLogger.shared.error("TextInserter: failed to create CGEvent for Cmd+V")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
