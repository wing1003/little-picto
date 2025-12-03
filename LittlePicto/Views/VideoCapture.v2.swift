import AVFoundation
import CoreVideo
import UIKit
import Vision

/// Protocol for receiving video frame callbacks.
@MainActor
public protocol VideoCaptureDelegateV2: AnyObject {
    func onFrame(pixelBuffer: CVPixelBuffer)
    func onInferenceTime(speed: Double, fps: Double)
}

func bestCaptureDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if UserDefaults.standard.bool(forKey: "use_telephoto"),
       let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: position) {
        return device
    } else if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position) {
        return device
    } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
        return device
    } else {
        return AVCaptureDevice.default(for: .video)
    }
}

public class VideoCaptureV2: NSObject, @unchecked Sendable {
    public weak var delegate: VideoCaptureDelegateV2?
    public var previewLayer: AVCaptureVideoPreviewLayer?
    
    private enum PhotoCaptureError: Error {
        case noPhotoData
    }

    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let cameraQueue = DispatchQueue(label: "camera-queue")
    private var currentBuffer: CVPixelBuffer?
    private var photoCaptureCompletion: ((Result<UIImage, Error>) -> Void)?

    private var inferenceOK = true
    private var frameSizeCaptured = false
    private var longSide: CGFloat = 3
    private var shortSide: CGFloat = 4

    public func stopCapture() {
        captureSession.stopRunning()
    }

    public func startCapture() {
        captureSession.startRunning()
    }
    
    public func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            guard self.photoOutput.connections.first != nil else {
                DispatchQueue.main.async {
                    completion(.failure(PhotoCaptureError.noPhotoData))
                }
                return
            }
            self.photoCaptureCompletion = completion
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
//                settings.isHighResolutionPhotoEnabled = true
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Setup camera session
    public func setUp(
        sessionPreset: AVCaptureSession.Preset = .hd1280x720,
        position: AVCaptureDevice.Position,
        orientation: UIDeviceOrientation,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        cameraQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let success = self.setUpCamera(
                sessionPreset: sessionPreset,
                position: position,
                orientation: orientation
            )

            DispatchQueue.main.async { completion(success) }
        }
    }

    private func setUpCamera(
        sessionPreset: AVCaptureSession.Preset,
        position: AVCaptureDevice.Position,
        orientation: UIDeviceOrientation
    ) -> Bool {

        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset

        guard let device = bestCaptureDevice(position: position) else { return false }
        captureDevice = device

        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            print("Video input failed: \(error)")
            return false
        }

        guard let input = videoInput,
              captureSession.canAddInput(input) else { return false }

        captureSession.addInput(input)

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill

        switch orientation {
        case .landscapeLeft: preview.connection?.videoOrientation = .landscapeRight
        case .landscapeRight: preview.connection?.videoOrientation = .landscapeLeft
        default: preview.connection?.videoOrientation = .portrait
        }

        self.previewLayer = preview

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
        } catch { }

        captureSession.commitConfiguration()
        return true
    }

    /// Manual orientation update
    public func updateVideoOrientation(orientation: AVCaptureVideoOrientation) {
        guard let connection = videoOutput.connection(with: .video) else { return }
        connection.videoOrientation = orientation

        let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput
        connection.isVideoMirrored = (currentInput?.device.position == .front)

        previewLayer?.connection?.videoOrientation = orientation
    }

    /// Zoom
    public func setZoomRatio(ratio: CGFloat) {
        guard let device = captureDevice else { return }
        try? device.lockForConfiguration()
        device.videoZoomFactor = ratio
        device.unlockForConfiguration()
    }

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              currentBuffer == nil else { return }

        currentBuffer = pixelBuffer

        if !frameSizeCaptured {
            let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            longSide = max(w, h)
            shortSide = min(w, h)
            frameSizeCaptured = true
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onFrame(pixelBuffer: pixelBuffer)
        }

        currentBuffer = nil
    }
}

// MARK: - SampleBuffer Delegate
extension VideoCaptureV2: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard inferenceOK else { return }
        handleFrame(sampleBuffer)
    }
}

// MARK: - Photo Output Delegate
extension VideoCaptureV2: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async {
                self.photoCaptureCompletion?(.failure(error))
                self.photoCaptureCompletion = nil
            }
            return
        }
        
        guard
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            DispatchQueue.main.async {
                self.photoCaptureCompletion?(.failure(PhotoCaptureError.noPhotoData))
                self.photoCaptureCompletion = nil
            }
            return
        }
        
        DispatchQueue.main.async {
            self.photoCaptureCompletion?(.success(image))
            self.photoCaptureCompletion = nil
        }
    }
}
