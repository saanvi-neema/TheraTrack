import AVFoundation
import Vision

/// Wraps the front camera capture session and runs Vision's body-pose detector on
/// every frame, publishing the result on the main thread.
///
/// Marked `@unchecked Sendable`: delegate callbacks are confined to `processingQueue`
/// and `onPoseUpdate` is only ever invoked back on the main queue, so we take on the
/// synchronization guarantee ourselves rather than relying on the compiler to prove it.
final class PoseEstimationService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.theratrack.pose-processing")

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
        }

        session.commitConfiguration()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // The capture connection above already rotates/mirrors the buffer to upright,
        // so Vision needs no further correction here.
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first else { return }
            let recognizedPoints = try observation.recognizedPoints(.all)

            var points: [VNHumanBodyPoseObservation.JointName: (location: CGPoint, confidence: Float)] = [:]
            for (name, point) in recognizedPoints {
                points[name] = (location: point.location, confidence: point.confidence)
            }

            let timestamp = CMTimeGetSeconds(sampleBuffer.presentationTimeStamp)
            let snapshot = PoseSnapshot(points: points, timestamp: timestamp)

            DispatchQueue.main.async { [weak self] in
                self?.onPoseUpdate?(snapshot)
            }
        } catch {
            // Skip frames Vision fails to process (e.g. no person detected).
        }
    }
}
