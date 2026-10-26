import AVFoundation
import Vision
import simd

/// Wraps the camera capture session and runs Vision's 3D body-pose detector on
/// every frame, publishing the result on the main thread.
final class PoseEstimationService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.theratrack.pose-processing")

    /// `VNDetectHumanBodyPose3DRequest` is a stateful request — one instance is
    /// reused across every frame (not recreated per frame) so it can use temporal
    /// context across frames the way it's designed to.
    private let request3D = VNDetectHumanBodyPose3DRequest()

    private static let jointNames: [(String, VNHumanBodyPose3DObservation.JointName)] = [
        ("root", .root), ("centerShoulder", .centerShoulder),
        ("leftShoulder", .leftShoulder), ("rightShoulder", .rightShoulder),
        ("leftElbow", .leftElbow), ("rightElbow", .rightElbow),
        ("leftWrist", .leftWrist), ("rightWrist", .rightWrist),
        ("leftHip", .leftHip), ("rightHip", .rightHip),
        ("leftKnee", .leftKnee), ("rightKnee", .rightKnee),
        ("leftAnkle", .leftAnkle), ("rightAnkle", .rightAnkle)
    ]

    var onPoseUpdate: ((PoseSnapshot) -> Void)?

    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    func requestAccessAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.processingQueue.async {
                self.configureSessionIfNeeded()
                self.session.startRunning()
            }
        }
    }

    func stop() {
        processingQueue.async { [session] in
            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Correct the buffer's rotation/mirroring at the capture-connection level
        // (not by guessing a CGImagePropertyOrientation after the fact) so what Vision
        // sees is already an upright, naturally-mirrored "selfie" image.
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            connection.automaticallyAdjustsVideoMirroring = false
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            // Camera intrinsics improve monocular 3D depth-estimation accuracy.
            if connection.isCameraIntrinsicMatrixDeliverySupported {
                connection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        session.commitConfiguration()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Built from the sample buffer (not just the pixel buffer) so Vision can
        // pick up the attached camera-intrinsics metadata enabled above.
        let requestHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)

        do {
            try requestHandler.perform([request3D])
            guard let observation = request3D.results?.first else { return }

            var points2D: [String: (location: CGPoint, confidence: Float)] = [:]
            var points3D: [String: SIMD3<Float>] = [:]

            for (name, jointName) in Self.jointNames {
                // VNHumanBodyRecognizedPoint3D has no confidence score — an
                // unreliable joint throws here instead of returning a low-confidence
                // value, so successfully getting this far already is the filter.
                guard (try? observation.recognizedPoint(jointName)) != nil else { continue }
                let confidence: Float = 1.0

                if let imagePoint = try? observation.pointInImage(jointName) {
                    points2D[name] = (location: CGPoint(x: imagePoint.x, y: imagePoint.y), confidence: confidence)
                }
                if let cameraRelative = try? observation.cameraRelativePosition(jointName) {
                    let translation = cameraRelative.columns.3
                    points3D[name] = SIMD3<Float>(translation.x, translation.y, translation.z)
                }
            }

            let timestamp = CMTimeGetSeconds(sampleBuffer.presentationTimeStamp)
            let snapshot = PoseSnapshot(points2D: points2D, points3D: points3D, timestamp: timestamp)

            DispatchQueue.main.async { [weak self] in
                self?.onPoseUpdate?(snapshot)
            }
        } catch {
            // Skip frames Vision fails to process (e.g. no person detected).
        }
    }
}
