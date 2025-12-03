import SwiftUI
import UIKit

struct PhotoCropperSheet: View {
    let image: UIImage
    var onCancel: () -> Void
    var onConfirm: (UIImage) -> Void
    
    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropRect: CGRect = .zero
    @State private var containerSize: CGSize = .zero
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var activeHandle: CropHandle?
    
    private var cropPadding: CGFloat { 40 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Button("Done") {
                    guard !isUploading,
                          let cropped = generateCroppedImage() else { return }
                    upload(croppedImage: cropped)
                }
                .foregroundColor(.yellow)
                .disabled(isUploading)
            }
            .padding()
            .background(Color.black)
            
            // Crop area
            GeometryReader { geo in
                let size = geo.size
                
                ZStack {
                    Color.black
                    
                    // Image
                    GeometryReader { imageGeo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(currentScale)
                            .offset(offset)
                            .frame(width: imageGeo.size.width, height: imageGeo.size.height)
                            .gesture(imageDragGesture)
                            .gesture(imagePinchGesture)
                    }
                    
                    // Crop overlay
                    if cropRect.width > 0 && cropRect.height > 0 {
                        cropOverlay(in: size)
                    }
                }
                .onAppear {
                    containerSize = size
                    initializeCropRect(size: size)
                }
                .onChange(of: size) { newSize in
                    containerSize = newSize
                    if cropRect == .zero {
                        initializeCropRect(size: newSize)
                    }
                }
            }
            .clipped()
            
            if let uploadError {
                Text(uploadError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Bottom toolbar
            HStack {
                Button(action: {}) {
                    Image(systemName: "crop.rotate")
                        .font(.title3)
                }
                
                Spacer()
                
                Button(action: { resetCrop() }) {
                    Text("Reset")
                        .font(.system(size: 16))
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.black)
        }
        .background(Color.black)
        .overlay(alignment: .center) {
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var imageDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = constrainOffset(newOffset)
            }
            .onEnded { _ in
                lastOffset = constrainOffset(offset)
            }
    }
    
    private var imagePinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = min(max(lastScale * value, 1), 5)
                currentScale = newScale
                offset = constrainOffset(offset)
            }
            .onEnded { _ in
                lastScale = currentScale
                lastOffset = constrainOffset(offset)
            }
    }
    
    private func initializeCropRect(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let side = max(50, min(size.width, size.height) - cropPadding * 2)
        cropRect = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )
    }
    
    private func resetCrop() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
            initializeCropRect(size: containerSize)
        }
    }
    
    private func constrainOffset(_ proposedOffset: CGSize) -> CGSize {
        guard containerSize.width > 0 && containerSize.height > 0,
              cropRect.width > 0 && cropRect.height > 0 else {
            return proposedOffset
        }
        
        // Calculate the scaled image dimensions
        let baseScale = min(containerSize.width / image.size.width,
                            containerSize.height / image.size.height)
        let totalScale = baseScale * currentScale
        
        let scaledImageWidth = image.size.width * totalScale
        let scaledImageHeight = image.size.height * totalScale
        
        // Calculate image bounds in container coordinates
        let imageLeft = containerSize.width / 2 - scaledImageWidth / 2 + proposedOffset.width
        let imageRight = imageLeft + scaledImageWidth
        let imageTop = containerSize.height / 2 - scaledImageHeight / 2 + proposedOffset.height
        let imageBottom = imageTop + scaledImageHeight
        
        var constrainedOffset = proposedOffset
        
        // Constrain horizontally - image must cover crop area
        if scaledImageWidth <= cropRect.width {
            // Image is smaller than crop area, center it
            constrainedOffset.width = cropRect.midX - containerSize.width / 2
        } else {
            // Image is larger, ensure it covers crop area
            if imageLeft > cropRect.minX {
                constrainedOffset.width = proposedOffset.width - (imageLeft - cropRect.minX)
            }
            if imageRight < cropRect.maxX {
                constrainedOffset.width = proposedOffset.width + (cropRect.maxX - imageRight)
            }
        }
        
        // Constrain vertically - image must cover crop area
        if scaledImageHeight <= cropRect.height {
            // Image is smaller than crop area, center it
            constrainedOffset.height = cropRect.midY - containerSize.height / 2
        } else {
            // Image is larger, ensure it covers crop area
            if imageTop > cropRect.minY {
                constrainedOffset.height = proposedOffset.height - (imageTop - cropRect.minY)
            }
            if imageBottom < cropRect.maxY {
                constrainedOffset.height = proposedOffset.height + (cropRect.maxY - imageBottom)
            }
        }
        
        return constrainedOffset
    }
    
    private func cropOverlay(in size: CGSize) -> some View {
        ZStack {
            // Dimmed area outside crop
            EvenOddShape(mainRect: CGRect(origin: .zero, size: size), holeRect: cropRect)
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(Color.black.opacity(0.6))
            
            // Crop frame
            CropFrameView(cropRect: $cropRect, containerSize: size, activeHandle: $activeHandle)
        }
    }
    
    private func generateCroppedImage() -> UIImage? {
        guard containerSize != .zero,
              cropRect.width > 0,
              cropRect.height > 0,
              let cgImage = image.cgImage else { return nil }
        
        // Calculate how the image fits (same as .scaledToFit / .aspectRatio(.fit))
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        // Calculate the size the image takes up in the container when fitted
        let fittedSize: CGSize
        if imageAspect > containerAspect {
            // Image is wider - constrained by width
            fittedSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
        } else {
            // Image is taller - constrained by height
            fittedSize = CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        }
        
        // This is the base scale: how much we scale the original image to fit
        let baseScale = fittedSize.width / image.size.width
        
        // Apply user zoom
        let totalScale = baseScale * currentScale
        
        // Calculate actual displayed size with zoom
        let displayedSize = CGSize(
            width: image.size.width * totalScale,
            height: image.size.height * totalScale
        )
        
        // Calculate image position (center of container + offset)
        let imageOrigin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2 + offset.width,
            y: (containerSize.height - displayedSize.height) / 2 + offset.height
        )
        
        // Convert crop rect from view coordinates to image coordinates (in points)
        let cropX = (cropRect.minX - imageOrigin.x) / totalScale
        let cropY = (cropRect.minY - imageOrigin.y) / totalScale
        let cropWidth = cropRect.width / totalScale
        let cropHeight = cropRect.height / totalScale
        
        print("=== Crop Debug ===")
        print("Container: \(containerSize)")
        print("Image size (points): \(image.size)")
        print("CGImage size (pixels): \(cgImage.width)x\(cgImage.height)")
        print("Image orientation: \(image.imageOrientation.rawValue)")
        print("Crop in image (points): (\(cropX), \(cropY), \(cropWidth)x\(cropHeight))")
        
        // Create a properly oriented context to handle rotation
        let cropRectInPoints = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Clamp to image bounds (in points, respecting orientation)
        let clampedRect = CGRect(
            x: max(0, min(cropRectInPoints.minX, image.size.width)),
            y: max(0, min(cropRectInPoints.minY, image.size.height)),
            width: min(cropRectInPoints.width, image.size.width - max(0, cropRectInPoints.minX)),
            height: min(cropRectInPoints.height, image.size.height - max(0, cropRectInPoints.minY))
        )
        
        print("Clamped crop (points): \(clampedRect)")
        
        guard clampedRect.width > 0, clampedRect.height > 0 else {
            print("Invalid crop dimensions")
            return nil
        }
        
        // Draw the image properly oriented, then crop
        let scale = image.scale
        let pixelCropRect = CGRect(
            x: clampedRect.origin.x * scale,
            y: clampedRect.origin.y * scale,
            width: clampedRect.width * scale,
            height: clampedRect.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(clampedRect.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("Failed to create graphics context")
            return nil
        }
        
        // Draw the full image, then crop to the visible rect
        context.translateBy(x: -clampedRect.origin.x, y: -clampedRect.origin.y)
        image.draw(at: .zero)
        
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else {
            print("Failed to get image from context")
            return nil
        }
        
        print("Result size: \(result.size)")
        return result
    }

    private func upload(croppedImage: UIImage) {
        uploadError = nil
        isUploading = true
        APIService.shared.uploadImage(croppedImage) { result in
            DispatchQueue.main.async {
                isUploading = false
                switch result {
                case .success:
                    onConfirm(croppedImage)
                case .failure(let error):
                    uploadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Crop Handle

enum CropHandle {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right
}

// MARK: - Crop Frame View

struct CropFrameView: View {
    @Binding var cropRect: CGRect
    let containerSize: CGSize
    @Binding var activeHandle: CropHandle?
    
    private let handleSize: CGFloat = 44
    private let cornerSize: CGFloat = 24
    private let edgeThickness: CGFloat = 3
    
    var body: some View {
        ZStack {
            // Border
            Path { path in
                path.addRect(cropRect)
            }
            .stroke(Color.white, lineWidth: 2)
            
            // Grid lines
            GridLinesView(cropRect: cropRect)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
            
            // Corner handles
            cornerHandle(.topLeft)
            cornerHandle(.topRight)
            cornerHandle(.bottomLeft)
            cornerHandle(.bottomRight)
            
            // Edge handles
            edgeHandle(.top)
            edgeHandle(.bottom)
            edgeHandle(.left)
            edgeHandle(.right)
        }
    }
    
    private func cornerHandle(_ handle: CropHandle) -> some View {
        let position = handlePosition(for: handle)
        
        return ZStack {
            // Hit area
            Circle()
                .fill(Color.clear)
                .frame(width: handleSize, height: handleSize)
            
            // Visual corner
            CornerHandleShape()
                .stroke(Color.white, lineWidth: edgeThickness)
                .frame(width: cornerSize, height: cornerSize)
        }
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    activeHandle = handle
                    updateCropRect(for: handle, translation: value.translation)
                }
                .onEnded { _ in
                    activeHandle = nil
                }
        )
    }
    
    private func edgeHandle(_ handle: CropHandle) -> some View {
        let position = handlePosition(for: handle)
        let size = edgeHandleSize(for: handle)
        
        return Rectangle()
            .fill(Color.clear)
            .frame(width: max(0, size.width), height: max(0, size.height))
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        activeHandle = handle
                        updateCropRect(for: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                    }
            )
    }
    
    private func handlePosition(for handle: CropHandle) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        case .top:
            return CGPoint(x: cropRect.midX, y: cropRect.minY)
        case .bottom:
            return CGPoint(x: cropRect.midX, y: cropRect.maxY)
        case .left:
            return CGPoint(x: cropRect.minX, y: cropRect.midY)
        case .right:
            return CGPoint(x: cropRect.maxX, y: cropRect.midY)
        }
    }
    
    private func edgeHandleSize(for handle: CropHandle) -> CGSize {
        switch handle {
        case .top, .bottom:
            return CGSize(width: max(0, cropRect.width - handleSize * 2), height: handleSize)
        case .left, .right:
            return CGSize(width: handleSize, height: max(0, cropRect.height - handleSize * 2))
        default:
            return CGSize(width: handleSize, height: handleSize)
        }
    }
    
    private func updateCropRect(for handle: CropHandle, translation: CGSize) {
        let minSize: CGFloat = 100
        var newRect = cropRect
        
        switch handle {
        case .topLeft:
            let newX = cropRect.minX + translation.width
            let newY = cropRect.minY + translation.height
            let newWidth = cropRect.maxX - newX
            let newHeight = cropRect.maxY - newY
            
            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.x = max(0, newX)
                newRect.origin.y = max(0, newY)
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
            
        case .topRight:
            let newY = cropRect.minY + translation.height
            let newWidth = cropRect.width + translation.width
            let newHeight = cropRect.maxY - newY
            
            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.y = max(0, newY)
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
            
        case .bottomLeft:
            let newX = cropRect.minX + translation.width
            let newWidth = cropRect.maxX - newX
            let newHeight = cropRect.height + translation.height
            
            if newWidth >= minSize && newHeight >= minSize {
                newRect.origin.x = max(0, newX)
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
            
        case .bottomRight:
            let newWidth = cropRect.width + translation.width
            let newHeight = cropRect.height + translation.height
            
            if newWidth >= minSize && newHeight >= minSize {
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
            
        case .top:
            let newY = cropRect.minY + translation.height
            let newHeight = cropRect.maxY - newY
            
            if newHeight >= minSize {
                newRect.origin.y = max(0, newY)
                newRect.size.height = newHeight
            }
            
        case .bottom:
            let newHeight = cropRect.height + translation.height
            if newHeight >= minSize {
                newRect.size.height = newHeight
            }
            
        case .left:
            let newX = cropRect.minX + translation.width
            let newWidth = cropRect.maxX - newX
            
            if newWidth >= minSize {
                newRect.origin.x = max(0, newX)
                newRect.size.width = newWidth
            }
            
        case .right:
            let newWidth = cropRect.width + translation.width
            if newWidth >= minSize {
                newRect.size.width = newWidth
            }
        }
        
        // Keep within container bounds
        if newRect.maxX > containerSize.width {
            newRect.size.width = containerSize.width - newRect.minX
        }
        if newRect.maxY > containerSize.height {
            newRect.size.height = containerSize.height - newRect.minY
        }
        
        // Final validation
        if newRect.width > 0 && newRect.height > 0 {
            cropRect = newRect
        }
    }
}

// MARK: - Shapes

struct CornerHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = rect.width * 0.4
        
        // Top horizontal line
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: length, y: 0))
        
        // Left vertical line
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: length))
        
        return path
    }
}

struct GridLinesView: Shape {
    let cropRect: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard cropRect.width > 0 && cropRect.height > 0 else { return path }
        
        // Vertical lines
        path.move(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.minY))
        path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width / 3, y: cropRect.maxY))
        
        path.move(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.minY))
        path.addLine(to: CGPoint(x: cropRect.minX + cropRect.width * 2 / 3, y: cropRect.maxY))
        
        // Horizontal lines
        path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height / 3))
        path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height / 3))
        
        path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height * 2 / 3))
        path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height * 2 / 3))
        
        return path
    }
}

private struct EvenOddShape: Shape {
    let mainRect: CGRect
    let holeRect: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(mainRect)
        path.addRect(holeRect)
        return path
    }
}
