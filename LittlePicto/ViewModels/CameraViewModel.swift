import AVFoundation
import Photos
import UIKit

class CameraViewModel: NSObject, ObservableObject {
    @Published var isTorchOn = false
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var capturedImage: UIImage?

    private let capture = VideoCaptureV2()
    
    // Expose the internal session from VideoCaptureV2
    // Note: VideoCaptureV2 doesn't expose its session, so we'll need to modify the approach

    override init() {
        super.init()
        // Set up the camera
        capture.setUp(
            sessionPreset: .hd1280x720,
            position: .back,
            orientation: .portrait
        ) { [weak self] success in
            guard let self else { return }
            if success {
                self.previewLayer = self.capture.previewLayer
                print("Camera setup successful")
            } else {
                self.previewLayer = nil
                print("Camera setup failed")
            }
        }
    }

    func start() {
        capture.startCapture()
    }

    func stop() {
        capture.stopCapture()
    }

    func flipCamera() {
        // Need to implement in VideoCaptureV2
    }

    func toggleTorch() {
        isTorchOn.toggle()
        // Need to implement in VideoCaptureV2
    }

    func capturePhoto() {
        capture.capturePhoto { [weak self] result in
            switch result {
            case .success(let image):
                DispatchQueue.main.async {
                    self?.stop()
                    self?.capturedImage = image
                }
            case .failure(let error):
                print("❌ Photo capture failed: \(error.localizedDescription)")
            }
        }
    }
    
    func resetCapture() {
        capturedImage = nil
    }

    func saveCroppedPhoto(_ image: UIImage, completion: (() -> Void)? = nil) {
        saveToPhotoLibrary(image, completion: completion)
        capturedImage = nil
    }
    
    private func saveToPhotoLibrary(_ image: UIImage, completion: (() -> Void)? = nil) {
        let saveBlock = {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            print("📸 Photo saved to library.")
            DispatchQueue.main.async {
                completion?()
            }
        }
        
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            switch status {
            case .authorized, .limited:
                saveBlock()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    if newStatus == .authorized || newStatus == .limited {
                        saveBlock()
                    } else {
                        print("⚠️ Photo Library access denied.")
                    }
                }
            default:
                print("⚠️ Photo Library access denied.")
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                saveBlock()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    if newStatus == .authorized {
                        saveBlock()
                    } else {
                        print("⚠️ Photo Library access denied.")
                    }
                }
            default:
                print("⚠️ Photo Library access denied.")
            }
        }
    }
}
