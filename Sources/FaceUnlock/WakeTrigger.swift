import AppKit
import CoreGraphics
import Foundation

final class WakeTrigger: @unchecked Sendable {
    static let ownEventTag: Int64 = 0x4655_4E4C

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var onTrigger: (@MainActor @Sendable () -> Void)?
    private var lastFire = Date.distantPast

    static var hasInputMonitoring: Bool { CGPreflightListenEventAccess() }

    @discardableResult
    static func requestInputMonitoring() -> Bool { CGRequestListenEventAccess() }

    @discardableResult
    func start(_ onTrigger: @escaping @MainActor @Sendable () -> Void) -> Bool {
        stop()
        self.onTrigger = onTrigger
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let trigger = Unmanaged<WakeTrigger>.fromOpaque(refcon).takeUnretainedValue()
                trigger.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        onTrigger = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.ownEventTag,
              Date().timeIntervalSince(lastFire) > 1 else { return }
        lastFire = Date()
        let trigger = onTrigger
        MainActor.assumeIsolated { trigger?() }
    }
}
