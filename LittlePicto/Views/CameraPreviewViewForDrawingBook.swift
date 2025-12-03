import SwiftUI
import AVFoundation

struct CameraPreviewViewForDrawingBook: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        attachPreviewLayer(to: view)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        attachPreviewLayer(to: uiView)
    }
    
    private func attachPreviewLayer(to view: UIView) {
        // Remove any existing preview layer before attaching a new one
        view.layer.sublayers?
            .filter { $0 is AVCaptureVideoPreviewLayer }
            .forEach { $0.removeFromSuperlayer() }
        
        guard let previewLayer else { return }
        
        previewLayer.removeFromSuperlayer()
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }
}
