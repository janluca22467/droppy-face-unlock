@preconcurrency import AVFoundation
import AppKit
import DroppyKit
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        if nsView.previewLayer.session !== session { nsView.previewLayer.session = session }
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            previewLayer.videoGravity = .resizeAspectFill
            layer = CALayer()
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
            CATransaction.commit()
        }
    }
}

struct FaceTickRing: View {
    var progress: Double
    var tint: Color
    var sweeping: Bool
    var tickCount = 72

    var body: some View {
        TimelineView(.animation(paused: !sweeping)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outer = min(size.width, size.height) / 2
                let length = outer * 0.085
                let inner = outer - length
                let lit = Int((progress * Double(tickCount)).rounded())
                let head = sweeping ? (t * 0.9).truncatingRemainder(dividingBy: 1) : -1

                for i in 0..<tickCount {
                    let fraction = Double(i) / Double(tickCount)
                    let angle = fraction * 2 * .pi - .pi / 2
                    let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                    var path = Path()
                    path.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
                    path.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))

                    var color = Color.white.opacity(0.16)
                    if i < lit {
                        color = tint
                    } else if head >= 0 {
                        let behind = (head - fraction + 1).truncatingRemainder(dividingBy: 1)
                        if behind < 0.22 { color = Color.white.opacity(0.16 + 0.6 * (1 - behind / 0.22)) }
                    }
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: outer * 0.022, lineCap: .round))
                }
            }
        }
    }
}

struct FaceScanHero: View {
    @ObservedObject var droplet: FaceUnlockDroplet
    @State private var bounce = 0

    private let size: CGFloat = 196

    var body: some View {
        VStack(spacing: DroppySpacing.lg) {
            ZStack {
                portrait
                    .frame(width: size * 0.8, height: size * 0.8)
                    .clipShape(Circle())
                FaceTickRing(progress: ringProgress, tint: ringTint, sweeping: isSweeping)
                    .frame(width: size, height: size)
                if case .enrolling(let step, _, _) = droplet.scan {
                    PoseArrow(pose: EnrollStep.all[min(step, EnrollStep.all.count - 1)].pose, size: size)
                }
                if case .enrolled = droplet.scan { successBadge }
                if case .testing(_, _, _, true) = droplet.scan { successBadge }
            }
            .frame(width: size, height: size)
            .animation(.spring(duration: 0.45), value: droplet.scan)

            VStack(spacing: DroppySpacing.xs) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.opacity)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: 360)

            if case .enrolling(let step, let inStep, _) = droplet.scan {
                StepDots(step: step, inStep: inStep)
                    .transition(.opacity)
            }

            if case .testing(_, let distance, _, _) = droplet.scan {
                DistanceGauge(distance: distance, best: droplet.bestTestDistance, limit: droplet.threshold)
                    .frame(width: 280)
                    .transition(.opacity)
            }

            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DroppySpacing.xl)
    }

    @ViewBuilder private var portrait: some View {
        if droplet.isScanning {
            CameraPreview(session: droplet.recognizer.session)
                .overlay(Circle().fill(Color.black.opacity(dimsCamera ? 0.35 : 0)))
                .transition(.opacity)
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(DroppyOpacity.light))
                Image(systemName: droplet.hasFaceEnrolled ? "faceid" : "person.crop.circle.badge.plus")
                    .font(.system(size: 54, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(droplet.hasFaceEnrolled ? Color.green : Color.secondary)
            }
            .transition(.opacity)
        }
    }

    private var successBadge: some View {
        ZStack {
            Circle().fill(Color.green).frame(width: 44, height: 44)
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce)
        }
        .shadow(color: .green.opacity(0.5), radius: 12)
        .offset(x: size * 0.33, y: size * 0.33)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
        .onAppear { bounce += 1 }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: DroppySpacing.sm) {
            switch droplet.scan {
            case .enrolling:
                Button(L.s("hero.cancel")) { droplet.cancelScan() }
                    .buttonStyle(DroppyQuietButtonStyle(size: .medium))
            case .testing(_, _, _, let matched):
                if !matched, let best = droplet.bestTestDistance, Double(best) > droplet.threshold {
                    Button {
                        droplet.adoptBestDistance()
                    } label: {
                        Label(L.f("hero.adopt", min(Double(best) + 0.04, 1.5)), systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(DroppyAccentButtonStyle(size: .medium))
                }
                Button(L.s(matched ? "hero.done" : "hero.cancel")) { droplet.cancelScan() }
                    .buttonStyle(DroppyQuietButtonStyle(size: .medium))
            case .none, .enrolled:
                Button {
                    droplet.startEnrollment()
                } label: {
                    Label(L.s(droplet.hasFaceEnrolled ? "hero.rescan" : "hero.scan"), systemImage: "faceid")
                }
                .buttonStyle(DroppyAccentButtonStyle(size: .medium))
                .disabled(droplet.cameraStatus != .granted)

                if droplet.hasFaceEnrolled {
                    Button {
                        droplet.startTest()
                    } label: {
                        Label(L.s("hero.test"), systemImage: "eye")
                    }
                    .buttonStyle(DroppyQuietButtonStyle(size: .medium))
                    .disabled(droplet.cameraStatus != .granted)
                }
            }
        }
        .droppyFlatGlassControls()
    }

    private var isSweeping: Bool {
        switch droplet.scan {
        case .enrolling: return true
        case .testing(_, _, _, let matched): return !matched
        case .none, .enrolled: return false
        }
    }

    private var dimsCamera: Bool {
        if case .testing(_, _, _, true) = droplet.scan { return true }
        return false
    }

    private var ringProgress: Double {
        switch droplet.scan {
        case .enrolling(_, _, let total): return Double(total) / Double(EnrollStep.totalSamples)
        case .enrolled: return 1
        case .testing(_, _, _, let matched): return matched ? 1 : 0
        case .none: return droplet.hasFaceEnrolled ? 1 : 0
        }
    }

    private var ringTint: Color {
        if case .none = droplet.scan, droplet.hasFaceEnrolled { return .green.opacity(0.55) }
        return .green
    }

    private var title: String {
        switch droplet.scan {
        case .enrolling(let step, _, _):
            switch EnrollStep.all[min(step, EnrollStep.all.count - 1)].pose {
            case .center: return L.s(step == 0 ? "step.center0" : "step.center1")
            case .left: return L.s("step.left")
            case .right: return L.s("step.right")
            case .up: return L.s("step.up")
            case .down: return L.s("step.down")
            }
        case .enrolled: return L.s("hero.saved")
        case .testing(_, _, _, true): return L.s("lock.recognizedShort")
        case .testing(false, _, _, _): return L.s("hero.noFace")
        case .testing(true, let d?, _, _) where Double(d) > droplet.threshold: return L.s("hero.notYet")
        case .testing(true, _, false, _): return L.s("hero.blinkNow")
        case .testing: return L.s("hero.checking")
        case .none: return L.s(droplet.hasFaceEnrolled ? "hero.ready" : "hero.setup")
        }
    }

    private var subtitle: String {
        switch droplet.scan {
        case .enrolling(let step, _, let total):
            return L.f("hero.progress", min(step + 1, EnrollStep.all.count), EnrollStep.all.count, total, EnrollStep.totalSamples)
        case .enrolled:
            return L.f("hero.savedDetail", FaceUnlockDroplet.enrollSamples, droplet.threshold)
        case .testing(_, let distance, _, let matched):
            let value = distance.map { L.f("hero.distance", $0) } ?? L.s("hero.distanceNone")
            let limit = L.f("hero.limit", droplet.threshold)
            if matched { return L.f("hero.matchedDetail", value, limit) }
            if let d = distance, Double(d) > droplet.threshold {
                return L.f("hero.tooFar", value, limit)
            }
            return "\(value) · \(limit)"
        case .none:
            return droplet.hasFaceEnrolled
                ? L.s("hero.readyDetail")
                : L.s("hero.setupDetail")
        }
    }
}

struct FaceHUDStrip: View {
    let phase: FaceUnlockDroplet.Phase

    static func label(for phase: FaceUnlockDroplet.Phase) -> String {
        switch phase {
        case .idle, .timedOut, .waiting, .blocked: return ""
        case .scanning: return L.s("ax.scanning")
        case .faceSeen: return L.s("ax.faceSeen")
        case .recognized: return L.s("ax.recognized")
        case .unlocking: return L.s("lock.unlocked")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            FaceHUDGlyph(phase: phase)
                .frame(width: 18, height: 18)
            Spacer(minLength: DroppySpacing.sm)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(phase == .recognized || phase == .unlocking ? Color.green : AdaptiveColors.notchSurfaceSecondaryText)
                .lineLimit(1)
                .id(text)
                .transition(DroppyTransition.compactContent)
        }
        .padding(.horizontal, DroppySpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var text: String {
        switch phase {
        case .idle, .timedOut, .waiting, .blocked: return ""
        case .scanning: return L.s("hud.searching")
        case .faceSeen: return L.s("lock.blinkShort")
        case .recognized: return L.s("lock.recognizedShort")
        case .unlocking: return L.s("lock.unlocked")
        }
    }
}

struct FaceHUDGlyph: View {
    let phase: FaceUnlockDroplet.Phase

    var body: some View {
        ZStack {
            switch phase {
            case .recognized, .unlocking:
                Image(systemName: phase == .unlocking ? "lock.open.fill" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
                    .transition(DroppyTransition.compactContent)
            default:
                TimelineView(.animation) { timeline in
                    let angle = timeline.date.timeIntervalSinceReferenceDate * 300
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(phase == .faceSeen ? Color.green : Color.white.opacity(0.9),
                                style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .rotationEffect(.degrees(angle))
                }
                Image(systemName: "faceid")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            }
        }
    }
}

struct FaceHUDCard: View {
    let phase: FaceUnlockDroplet.Phase
    let name: String
    @State private var bounce = 0

    var body: some View {
        HStack(spacing: DroppySpacing.lg) {
            ZStack {
                FaceTickRing(progress: 1, tint: .green, sweeping: false, tickCount: 48)
                    .frame(width: 64, height: 64)
                Image(systemName: phase == .unlocking ? "lock.open.fill" : "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: bounce)
                    .contentTransition(.symbolEffect(.replace))
            }
            VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                Text(L.f("card.hello", name))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                Text(L.s(phase == .unlocking ? "note.unlocked" : "card.recognized"))
                    .font(.system(size: 12))
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    .id(phase)
                    .transition(DroppyTransition.element)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DroppySpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { bounce += 1 }
        .onChange(of: phase) { bounce += 1 }
    }
}

struct DistanceGauge: View {
    let distance: Float?
    let best: Float?
    let limit: Double

    private let maxValue = 1.5

    var body: some View {
        VStack(spacing: DroppySpacing.xs) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(DroppyOpacity.light))
                    Capsule()
                        .fill(Color.green.opacity(0.35))
                        .frame(width: x(limit, w))
                    if let best {
                        Circle().fill(Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .offset(x: x(Double(best), w) - 3)
                    }
                    if let distance {
                        Circle()
                            .fill(Double(distance) <= limit ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: x(Double(distance), w) - 6)
                            .animation(.easeOut(duration: 0.2), value: distance)
                    }
                    Rectangle().fill(Color.green)
                        .frame(width: 2, height: 14)
                        .offset(x: x(limit, w) - 1)
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            HStack {
                Text(L.s("gauge.similar"))
                Spacer()
                Text(best.map { L.f("gauge.best", $0) } ?? "")
                Spacer()
                Text(L.s("gauge.different"))
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }

    private func x(_ value: Double, _ width: CGFloat) -> CGFloat {
        CGFloat(min(max(value / maxValue, 0), 1)) * width
    }
}

struct PoseArrow: View {
    let pose: EnrollStep.Pose
    let size: CGFloat

    var body: some View {
        if let (symbol, offset) = placement {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .symbolEffect(.pulse)
                .offset(offset)
                .id(symbol)
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
        }
    }

    private var placement: (String, CGSize)? {
        let r = size * 0.3
        switch pose {
        case .center: return nil
        case .left: return ("chevron.left", CGSize(width: -r, height: 0))
        case .right: return ("chevron.right", CGSize(width: r, height: 0))
        case .up: return ("chevron.up", CGSize(width: 0, height: -r))
        case .down: return ("chevron.down", CGSize(width: 0, height: r))
        }
    }
}

struct StepDots: View {
    let step: Int
    let inStep: Int

    var body: some View {
        HStack(spacing: DroppySpacing.xsm) {
            ForEach(EnrollStep.all.indices, id: \.self) { i in
                let fill: Double = i < step ? 1 : (i == step ? Double(inStep) / Double(EnrollStep.all[i].samples) : 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(DroppyOpacity.visible))
                    Capsule().fill(Color.green)
                        .frame(width: 28 * fill)
                }
                .frame(width: 28, height: 5)
            }
        }
        .animation(.easeOut(duration: 0.25), value: inStep)
    }
}
