import AppKit
import AVFoundation
import Combine
import DroppyKit
import SwiftUI

@objc(FaceUnlockPrincipal)
public final class FaceUnlockPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { FaceUnlockDroplet() }
}

@MainActor
public final class FaceUnlockDroplet: NSObject, ObservableObject, Droplet {
    public nonisolated static let id: DropletID = "face-unlock"

    enum Phase: Hashable {
        case idle
        case waiting
        case blocked(String)
        case scanning, faceSeen, recognized, unlocking, timedOut
    }

    enum Scan: Equatable {
        case none
        case enrolling(step: Int, inStep: Int, total: Int)
        case testing(face: Bool, distance: Float?, blinked: Bool, matched: Bool)
        case enrolled
    }

    private static let hudID = "face-unlock-hud"
    private static let scanTimeout: TimeInterval = 30
    static var enrollSamples: Int { EnrollStep.totalSamples }
    static let looseThreshold = 0.8

    private var host: DropletHost?
    let recognizer = FaceRecognizer()
    private let wakeTrigger = WakeTrigger()
    private var lockRowTask: Task<Void, Never>?
    private var scanStarted = Date()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timeoutTask: Task<Void, Never>?
    private var unlockTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private let lockScreenSubject = CurrentValueSubject<LockScreenStatusEntry?, Never>(nil)

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var scan: Scan = .none
    @Published private(set) var hasPasswordSaved = PasswordStore.hasPassword
    @Published private(set) var hasFaceEnrolled = false
    @Published private(set) var isLocked = false
    @Published private(set) var lastEvent: String?
    @Published private(set) var bestTestDistance: Float?

    private var isHarness: Bool { host?.environment.isHarness ?? false }

    public func activate(host: DropletHost) throws {
        self.host = host
        try? FileManager.default.removeItem(at: legacyFaceFileURL)
        hasFaceEnrolled = loadTemplate() != nil
        hasPasswordSaved = PasswordStore.hasPassword

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked") { $0.screenLocked() }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.screenUnlocked() }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.screensDidWakeNotification.rawValue) { $0.userAskedToScan(L.s("why.wake")) }
        observe(distributed, "com.apple.screensaver.didstop") { $0.userAskedToScan(L.s("why.saver")) }
        lastEvent = host.preferences.value(forKey: "lastEvent", as: String.self)

        if host.environment.isHarness {
            let demo = ProcessInfo.processInfo.environment["FACE_UNLOCK_DEMO"]
            setPhase(demo == "scan" ? .faceSeen : .recognized)
            if demo == "enroll" { scan = .enrolling(step: 1, inStep: 6, total: 18) }
            if demo == "test" { scan = .testing(face: true, distance: 0.31, blinked: true, matched: true); bestTestDistance = 0.29 }
        }
    }

    public func deactivate() {
        stopEverything()
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        host?.hud.dismiss(id: Self.hudID)
        lockScreenSubject.send(nil)
        host = nil
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ action: @escaping @MainActor (FaceUnlockDroplet) -> Void) {
        let token = center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in if let self { action(self) } }
        }
        observers.append((center, token))
    }

    private func stopEverything() {
        timeoutTask?.cancel(); timeoutTask = nil
        unlockTask?.cancel(); unlockTask = nil
        resetTask?.cancel(); resetTask = nil
        lockRowTask?.cancel(); lockRowTask = nil
        wakeTrigger.stop()
        recognizer.stop()
        scan = .none
        phase = .idle
    }

    var isEnabled: Bool { host?.preferences.value(forKey: "enabled", default: false) ?? false }

    var isEnabledBinding: Binding<Bool> {
        Binding(get: { self.isEnabled }, set: { self.host?.preferences.setValue($0, forKey: "enabled"); self.objectWillChange.send() })
    }

    var threshold: Double { host?.preferences.value(forKey: "threshold", default: 0.45) ?? 0.45 }

    var thresholdBinding: Binding<Double> {
        Binding(get: { self.threshold }, set: { self.host?.preferences.setValue($0, forKey: "threshold"); self.objectWillChange.send() })
    }

    var defaultUsername: String { isHarness ? "alex" : NSUserName() }

    var username: String { host?.preferences.value(forKey: "username", default: defaultUsername) ?? defaultUsername }

    var typesUsername: Bool { host?.preferences.value(forKey: "typesUsername", default: false) ?? false }

    var typesUsernameBinding: Binding<Bool> {
        Binding(get: { self.typesUsername }, set: { self.host?.preferences.setValue($0, forKey: "typesUsername"); self.objectWillChange.send() })
    }

    var firstName: String {
        if isHarness { return "Alex" }
        return NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName()
    }

    private func screenLocked() {
        isLocked = true
        cancelScan()
        guard isEnabled else { note(L.s("note.lockedOff")); return }
        if let reason = blockedReason {
            note(L.f("note.lockedNotReady", reason))
            setPhase(.blocked(reason))
            return
        }
        let listening = wakeTrigger.start { [weak self] in self?.userAskedToScan(L.s("why.key")) }
        note(L.s(listening ? "note.waitingKey" : "note.waitingWake"))
        setPhase(.waiting)
    }

    private func userAskedToScan(_ why: String) {
        guard isLocked else { return }
        switch phase {
        case .waiting, .timedOut, .idle:
            note(L.f("note.trigger", why))
            beginScan()
        case .scanning, .faceSeen:
            restartTimeout()
        case .blocked, .recognized, .unlocking:
            break
        }
    }

    private var blockedReason: String? {
        guard isEnabled else { return L.s("reason.off") }
        if loadTemplate() == nil { return L.s("reason.noFace") }
        if !PasswordStore.hasPassword { return L.s("reason.noPassword") }
        if cameraStatus != .granted { return L.s("reason.camera") }
        if !KeyTyper.isTrusted { return L.s("reason.accessibility") }
        return nil
    }

    private func note(_ text: String) {
        let stamp = Date().formatted(date: .omitted, time: .shortened)
        lastEvent = "\(stamp) · \(text)"
        host?.preferences.setValue(lastEvent, forKey: "lastEvent")
        host?.log.info("Face Unlock: \(text)")
    }

    private func screenUnlocked() {
        isLocked = false
        let wasUnlocking = phase == .unlocking || phase == .recognized
        if wasUnlocking { note(L.s("note.unlocked")) }
        wakeTrigger.stop()
        lockRowTask?.cancel(); lockRowTask = nil
        timeoutTask?.cancel(); timeoutTask = nil
        unlockTask?.cancel(); unlockTask = nil
        recognizer.stop()
        lockScreenSubject.send(nil)
        if wasUnlocking {
            setPhase(.unlocking)
            resetTask?.cancel()
            resetTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                self?.phase = .idle
                self?.host?.hud.dismiss(id: Self.hudID)
            }
        } else {
            phase = .idle
            host?.hud.dismiss(id: Self.hudID)
        }
    }

    private func beginScan() {
        guard let host else { return }
        if let reason = blockedReason {
            setPhase(.blocked(reason))
            return
        }
        guard let face = loadTemplate() else { return }
        let started = recognizer.start(mode: .unlock, template: face, threshold: Float(threshold)) { [weak self] event in
            Task { @MainActor in self?.handleUnlock(event) }
        }
        guard started else {
            note(L.s("note.noCamera"))
            host.log.notice("Face Unlock: no camera")
            return
        }
        setPhase(.scanning)
        restartTimeout()
    }

    private func restartTimeout() {
        scanStarted = Date()
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.scanTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.scanTimedOut()
        }
    }

    private func scanTimedOut() {
        recognizer.stop()
        note(L.s("note.timeout"))
        setPhase(.timedOut)
        host?.hud.dismiss(id: Self.hudID)
    }

    private func handleUnlock(_ event: FaceRecognizer.Event) {
        switch event {
        case .face(let seen):
            guard phase == .scanning || phase == .faceSeen else { return }
            setPhase(seen ? .faceSeen : .scanning)
        case .matched:
            guard phase == .scanning || phase == .faceSeen else { return }
            recognizer.stop()
            timeoutTask?.cancel()
            setPhase(.recognized)
            unlock()
        case .distance, .blinked, .enroll, .enrollDone:
            break
        }
    }

    private func unlock() {
        unlockTask?.cancel()
        let username = typesUsername ? self.username : nil
        unlockTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self, !Task.isCancelled, self.isLocked, let password = PasswordStore.load() else { return }
            KeyTyper.wake()
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, self.isLocked else { return }
            await KeyTyper.typeCredentials(username: username, password: password)
        }
    }

    private func setPhase(_ new: Phase) {
        guard phase != new else { return }
        phase = new
        publishLockScreen()
        presentHUD()
    }

    private func publishLockScreen() {
        lockRowTask?.cancel(); lockRowTask = nil
        switch phase {
        case .idle:
            lockScreenSubject.send(nil)
        case .waiting, .timedOut:
            lockScreenSubject.send(.init(id: "face", systemImage: "faceid",
                                         text: L.s(phase == .timedOut ? "lock.timeout" : "lock.pressKey"),
                                         detail: "Face Unlock", roundedCenterText: nil, roundedBottomText: L.s("lock.key"), progress: nil))
        case .blocked(let reason):
            lockScreenSubject.send(.init(id: "face", systemImage: "exclamationmark.triangle.fill",
                                         text: L.f("lock.blocked", reason), detail: nil))
        case .scanning, .faceSeen:
            lockRowTask = Task { [weak self] in
                while let self, !Task.isCancelled {
                    let left = max(0, 1 - Date().timeIntervalSince(self.scanStarted) / Self.scanTimeout)
                    let seen = self.phase == .faceSeen
                    self.lockScreenSubject.send(.init(
                        id: "face",
                        systemImage: seen ? "eye" : "faceid",
                        text: L.s(seen ? "lock.blink" : "lock.searching"),
                        detail: "Face Unlock",
                        roundedCenterText: "\(Int((left * Self.scanTimeout).rounded(.up)))",
                        roundedBottomText: L.s(seen ? "lock.blinkShort" : "lock.scanShort"),
                        progress: left
                    ))
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        case .recognized:
            lockScreenSubject.send(.init(id: "face", systemImage: "checkmark.circle.fill", text: L.s("lock.recognized"),
                                         detail: "Face Unlock", roundedCenterText: "✓", roundedBottomText: L.s("lock.recognizedShort"), progress: 1))
        case .unlocking:
            lockScreenSubject.send(.init(id: "face", systemImage: "lock.open.fill", text: L.s("lock.unlocked"), detail: "Face Unlock"))
        }
    }

    private func presentHUD() {
        guard let host else { return }
        let phase = self.phase
        switch phase {
        case .idle, .timedOut, .waiting, .blocked:
            host.hud.dismiss(id: Self.hudID)
            return
        case .scanning, .faceSeen, .recognized, .unlocking:
            break
        }
        let name = firstName
        let expanded = phase == .recognized || phase == .unlocking
        let request = DropletHUDRequest(
            id: Self.hudID,
            duration: nil,
            priority: .high,
            accessibilityLabel: FaceHUDStrip.label(for: phase),
            isExpanded: expanded,
            expandedContentHeight: 132
        ) {
            FaceHUDStrip(phase: phase)
        } expanded: {
            FaceHUDCard(phase: phase, name: name)
        }
        _ = host.hud.present(request)
    }

    var isScanning: Bool {
        switch scan {
        case .enrolling, .testing: return true
        case .none, .enrolled: return false
        }
    }

    func startEnrollment() {
        guard let host, !isScanning else { return }
        resetTask?.cancel()
        scan = .enrolling(step: 0, inStep: 0, total: 0)
        let started = recognizer.start(mode: .enroll, template: nil, threshold: 0) { [weak self] event in
            Task { @MainActor in self?.handleEnroll(event) }
        }
        guard started else { scan = .none; host.log.notice("Face Unlock: no camera"); return }
    }

    private func handleEnroll(_ event: FaceRecognizer.Event) {
        guard case .enrolling = scan else { return }
        switch event {
        case .enroll(let step, let inStep, let total):
            withAnimation(.easeOut(duration: 0.25)) { scan = .enrolling(step: step, inStep: inStep, total: total) }
        case .enrollDone(let template):
            recognizer.stop()
            saveTemplate(template)
            hasFaceEnrolled = loadTemplate() != nil
            host?.preferences.setValue((template.suggestedThreshold * 100).rounded() / 100, forKey: "threshold")
            withAnimation(.spring(duration: 0.5)) { scan = .enrolled }
            resetTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled, self?.scan == .enrolled else { return }
                withAnimation { self?.scan = .none }
            }
        case .face, .distance, .blinked, .matched:
            break
        }
    }

    func startTest() {
        guard let host, !isScanning, let face = loadTemplate() else { return }
        bestTestDistance = nil
        scan = .testing(face: false, distance: nil, blinked: false, matched: false)
        let started = recognizer.start(mode: .test, template: face, threshold: Float(threshold)) { [weak self] event in
            Task { @MainActor in self?.handleTest(event) }
        }
        guard started else { scan = .none; host.log.notice("Face Unlock: no camera"); return }
    }

    private func handleTest(_ event: FaceRecognizer.Event) {
        guard case .testing(var face, var distance, var blinked, var matched) = scan else { return }
        switch event {
        case .face(let seen): face = seen
        case .distance(let d):
            distance = d
            bestTestDistance = min(bestTestDistance ?? d, d)
        case .blinked: blinked = true
        case .matched: matched = true
        case .enroll, .enrollDone: break
        }
        withAnimation(.easeOut(duration: 0.2)) {
            scan = .testing(face: face, distance: distance, blinked: blinked, matched: matched)
        }
    }

    func adoptBestDistance() {
        guard let best = bestTestDistance else { return }
        let limit = min((Double(best) + 0.04) * 100, 150).rounded() / 100
        host?.preferences.setValue(limit, forKey: "threshold")
        objectWillChange.send()
        cancelScan()
        startTest()
    }

    func cancelScan() {
        guard isScanning || scan == .enrolled else { return }
        recognizer.stop()
        withAnimation { scan = .none }
    }

    func deleteFace() {
        cancelScan()
        try? FileManager.default.removeItem(at: faceFileURL)
        hasFaceEnrolled = false
        host?.preferences.setValue(nil as Double?, forKey: "threshold")
    }

    func saveCredentials(username: String, password: String) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        host?.preferences.setValue(trimmed.isEmpty ? defaultUsername : trimmed, forKey: "username")
        if !password.isEmpty { hasPasswordSaved = PasswordStore.save(password) }
        objectWillChange.send()
    }

    func deletePassword() {
        PasswordStore.delete()
        hasPasswordSaved = false
    }

    var cameraStatus: DropletPermissionStatus { host?.permissions.status(for: .camera) ?? .unavailable }
    var accessibilityTrusted: Bool { KeyTyper.isTrusted }
    var inputMonitoring: Bool { WakeTrigger.hasInputMonitoring }

    func requestCamera() {
        Task {
            if cameraStatus == .denied {
                host?.permissions.openSystemSettings(for: .camera)
            } else {
                _ = await host?.permissions.request(.camera)
            }
            objectWillChange.send()
        }
    }

    func openAccessibilitySettings() {
        host?.permissions.openSystemSettings(for: .accessibility)
    }

    func requestInputMonitoring() {
        if !WakeTrigger.requestInputMonitoring(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        objectWillChange.send()
    }

    func refreshPermissions() { objectWillChange.send() }

    var readiness: [String] {
        var missing: [String] = []
        if !hasFaceEnrolled { missing.append(L.s("missing.face")) }
        if !hasPasswordSaved { missing.append(L.s("missing.password")) }
        if cameraStatus != .granted { missing.append(L.s("missing.camera")) }
        if !accessibilityTrusted { missing.append(L.s("missing.accessibility")) }
        return missing
    }

    private var containerURL: URL {
        host?.environment.containerDirectory ?? FileManager.default.temporaryDirectory
    }

    private var faceFileURL: URL { containerURL.appendingPathComponent("face-template.json") }
    private var legacyFaceFileURL: URL { containerURL.appendingPathComponent("face.data") }

    private func loadTemplate() -> FaceTemplate? {
        guard let data = try? Data(contentsOf: faceFileURL),
              let template = try? JSONDecoder().decode(FaceTemplate.self, from: data),
              !template.vectors.isEmpty else { return nil }
        return template
    }

    private func saveTemplate(_ template: FaceTemplate) {
        guard let data = try? JSONEncoder().encode(template) else { return }
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try? data.write(to: faceFileURL, options: [.atomic, .completeFileProtection])
    }
}

extension FaceUnlockDroplet: HUDPresenting {}

extension FaceUnlockDroplet: LockScreenStatusProviding {
    public var lockScreenStatus: AnyPublisher<LockScreenStatusEntry?, Never> {
        lockScreenSubject.eraseToAnyPublisher()
    }
}

extension FaceUnlockDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(FaceUnlockSettings(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: L.s("search.scan"), keywords: ["face", "scan", "camera", "unlock"]),
            SettingsSearchEntry(title: L.s("search.password"), keywords: ["password", "username", "keychain"]),
        ]
    }
}
