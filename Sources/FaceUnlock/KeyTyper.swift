import ApplicationServices
import CoreGraphics
import Foundation

enum KeyTyper {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    nonisolated(unsafe) private static let source: CGEventSource? = {
        let s = CGEventSource(stateID: .hidSystemState)
        s?.userData = WakeTrigger.ownEventTag
        return s
    }()

    static func wake() {
        press(0x38)
    }

    static func clearField() async {
        press(0x00, flags: .maskCommand)
        try? await Task.sleep(nanoseconds: 40_000_000)
        press(0x33)
        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 15_000_000)
            press(0x33)
        }
    }

    static func typeCredentials(username: String?, password: String) async {
        await clearField()
        try? await Task.sleep(nanoseconds: 80_000_000)
        if let username, !username.isEmpty {
            await type(username)
            press(0x30)
            try? await Task.sleep(nanoseconds: 120_000_000)
            await clearField()
        }
        await type(password)
        try? await Task.sleep(nanoseconds: 80_000_000)
        press(0x24)
    }

    private static func type(_ text: String) async {
        for scalar in text.unicodeScalars {
            var units = Array(String(scalar).utf16)
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
                e.post(tap: .cghidEventTap)
            }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }
    }

    private static func press(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            if !flags.isEmpty { e.flags = flags }
            e.post(tap: .cghidEventTap)
        }
    }
}
