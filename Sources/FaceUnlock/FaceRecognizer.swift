@preconcurrency import AVFoundation
import CoreImage
import Foundation
import Vision

struct FaceTemplate: Codable, Sendable {
    var vectors: [[Float]]
    var steps: [Int]

    static func distance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return .greatestFiniteMagnitude }
        var sum: Float = 0
        for i in a.indices {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sum.squareRoot()
    }

    func nearest(_ v: [Float]) -> Float {
        vectors.reduce(Float.greatestFiniteMagnitude) { min($0, Self.distance($1, v)) }
    }

    var suggestedThreshold: Double {
        var nearest: [Float] = []
        for i in vectors.indices {
            var best = Float.greatestFiniteMagnitude
            for j in vectors.indices where steps[j] != steps[i] {
                best = min(best, Self.distance(vectors[i], vectors[j]))
            }
            if best < .greatestFiniteMagnitude { nearest.append(best) }
        }
        guard !nearest.isEmpty else { return 0.45 }
        nearest.sort()
        let p90 = nearest[min(nearest.count - 1, Int(Double(nearest.count) * 0.9))]
        return min(max(Double(p90) * 1.1, 0.25), 0.8)
    }
}

struct EnrollStep: Sendable {
    enum Pose: Sendable { case center, left, right, up, down }
    let pose: Pose
    let samples: Int

    static let all: [EnrollStep] = [
        .init(pose: .center, samples: 12),
        .init(pose: .left, samples: 10),
        .init(pose: .right, samples: 10),
        .init(pose: .up, samples: 9),
        .init(pose: .down, samples: 9),
        .init(pose: .center, samples: 10),
    ]

    static var totalSamples: Int { all.reduce(0) { $0 + $1.samples } }
}

final class FaceRecognizer: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Mode: Sendable { case enroll, unlock, test }

    enum Event: Sendable {
        case face(Bool)
        case distance(Float)
        case blinked
        case matched
        case enroll(step: Int, inStep: Int, total: Int)
        case enrollDone(FaceTemplate)
    }

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "face-unlock.camera")

    private var onEvent: (@Sendable (Event) -> Void)?
    private var mode: Mode = .unlock
    private var template = FaceTemplate(vectors: [], steps: [])
    private var collected = FaceTemplate(vectors: [], steps: [])
    private var step = 0
    private var inStep = 0
    private var stepStarted = Date()
    private var neutralYaw: Double?
    private var neutralPitch: Double?
    private var lastWork = Date.distantPast
    private var hadFace = false
    private var sawOpenEyes = false
    private var blinked = false
    private var matchedDistance = false
    private var threshold: Float = 0.45

    func start(mode: Mode, template: FaceTemplate?, threshold: Float, onEvent: @escaping @Sendable (Event) -> Void) -> Bool {
        stop()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        queue.sync {
            self.mode = mode
            self.template = template ?? FaceTemplate(vectors: [], steps: [])
            self.collected = FaceTemplate(vectors: [], steps: [])
            self.step = 0
            self.inStep = 0
            self.stepStarted = Date()
            self.neutralYaw = nil
            self.neutralPitch = nil
            self.threshold = threshold
            self.hadFace = false
            self.sawOpenEyes = false
            self.blinked = false
            self.matchedDistance = false
            self.onEvent = onEvent
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        if session.canAddInput(input) { session.addInput(input) }
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        queue.async { [session] in session.startRunning() }
        return true
    }

    func stop() {
        output.setSampleBufferDelegate(nil, queue: nil)
        queue.sync {
            onEvent = nil
            if session.isRunning { session.stopRunning() }
        }
        session.beginConfiguration()
        for i in session.inputs { session.removeInput(i) }
        for o in session.outputs { session.removeOutput(o) }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastWork) > 0.12,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastWork = Date()

        let landmarks = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .upMirrored)
        let face = (try? handler.perform([landmarks])) != nil
            ? (landmarks.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width })
            : nil
        let hasFace = (face?.boundingBox.width ?? 0) > 0.15
        if hasFace != hadFace {
            hadFace = hasFace
            onEvent?(.face(hasFace))
        }
        guard hasFace, let face, let vector = featureVector(face: face, buffer: buffer) else { return }

        if mode == .enroll {
            enroll(vector, face: face)
            return
        }

        let best = template.nearest(vector)
        guard best < .greatestFiniteMagnitude else { return }
        onEvent?(.distance(best))
        if best <= threshold { matchedDistance = true }

        if let ratio = eyeOpenness(face) {
            if ratio > 0.22 { sawOpenEyes = true }
            if ratio < 0.12, sawOpenEyes, !blinked {
                blinked = true
                onEvent?(.blinked)
            }
        }
        if matchedDistance && blinked {
            onEvent?(.matched)
            if mode == .unlock { onEvent = nil }
            matchedDistance = false
            blinked = false
            sawOpenEyes = false
        }
    }

    private func enroll(_ vector: [Float], face: VNFaceObservation) {
        guard step < EnrollStep.all.count else { return }
        let current = EnrollStep.all[step]

        let yaw = face.yaw?.doubleValue ?? 0
        let pitch = face.pitch?.doubleValue ?? 0
        if current.pose == .center, step == 0, neutralYaw == nil {
            neutralYaw = yaw
            neutralPitch = pitch
        }
        let dy = yaw - (neutralYaw ?? 0)
        let dp = pitch - (neutralPitch ?? 0)

        let lenient = Date().timeIntervalSince(stepStarted) > 6
        let posed: Bool
        switch current.pose {
        case .center: posed = abs(dy) < 0.2 && abs(dp) < 0.2
        case .left: posed = dy < -0.12
        case .right: posed = dy > 0.12
        case .up: posed = dp < -0.08
        case .down: posed = dp > 0.08
        }
        guard posed || lenient else { return }

        if let last = collected.vectors.last, FaceTemplate.distance(last, vector) < 0.03 { return }

        collected.vectors.append(vector)
        collected.steps.append(step)
        inStep += 1
        onEvent?(.enroll(step: step, inStep: inStep, total: collected.vectors.count))

        if inStep >= current.samples {
            step += 1
            inStep = 0
            stepStarted = Date()
            if step >= EnrollStep.all.count {
                onEvent?(.enrollDone(collected))
                onEvent = nil
            } else {
                onEvent?(.enroll(step: step, inStep: 0, total: collected.vectors.count))
            }
        }
    }

    private func featureVector(face: VNFaceObservation, buffer: CVPixelBuffer) -> [Float]? {
        let ci = CIImage(cvPixelBuffer: buffer).oriented(.upMirrored)
        let w = ci.extent.width, h = ci.extent.height
        var r = face.boundingBox
        r = r.insetBy(dx: -r.width * 0.15, dy: -r.height * 0.15)
        let crop = ci.cropped(to: CGRect(x: r.minX * w, y: r.minY * h, width: r.width * w, height: r.height * h))
        let print = VNGenerateImageFeaturePrintRequest()
        guard (try? VNImageRequestHandler(ciImage: crop).perform([print])) != nil,
              let observation = print.results?.first,
              observation.elementType == .float else { return nil }
        return observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func eyeOpenness(_ face: VNFaceObservation) -> CGFloat? {
        guard let l = face.landmarks?.leftEye?.normalizedPoints,
              let r = face.landmarks?.rightEye?.normalizedPoints,
              l.count > 4, r.count > 4 else { return nil }
        func ratio(_ p: [CGPoint]) -> CGFloat {
            let xs = p.map(\.x), ys = p.map(\.y)
            let width = (xs.max() ?? 0) - (xs.min() ?? 0)
            let height = (ys.max() ?? 0) - (ys.min() ?? 0)
            return width > 0 ? height / width : 0
        }
        return (ratio(l) + ratio(r)) / 2
    }
}
