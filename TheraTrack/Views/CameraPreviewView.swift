import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer = previewLayer
    }

    /// Keeps the preview layer's frame in sync with the view's actual bounds on every
    /// layout pass — relying on `updateUIView` alone can leave the layer at a zero-size
    /// frame since SwiftUI doesn't guarantee it runs after final layout.
    final class PreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                guard oldValue !== previewLayer else { return }
                oldValue?.removeFromSuperlayer()
                if let previewLayer {
                    layer.addSublayer(previewLayer)
                    setNeedsLayout()
                }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
