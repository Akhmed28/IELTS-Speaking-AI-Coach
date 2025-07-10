import SwiftUI

struct PhotoCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    
    private let cropSize: CGFloat = DesignSystem.Photo.cropSize
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    // Background dimming overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                    
                    // Image with proper constraints
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(constrainedOffset(in: geometry))
                        .onAppear {
                            calculateInitialImageSize(in: geometry)
                        }
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        
                                        let newScale = scale * delta
                                        // Ensure minimum scale keeps image larger than crop area
                                        let minScale = max(0.8, cropSize / min(imageSize.width, imageSize.height))
                                        scale = max(minScale, min(3.0, newScale))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        // Re-constrain offset after scaling
                                        offset = calculateConstrainedOffset(offset, in: geometry)
                                        lastOffset = offset
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = calculateConstrainedOffset(newOffset, in: geometry)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                    
                    // Crop overlay with proper masking
                    cropOverlay()
                    
                    // Instructions and controls
                    VStack {
                        Text("Move and Pinch to Crop")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 50)
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 40) {
                            Button("Cancel") {
                                onCancel()
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(25)
                            
                            Button("Use Photo") {
                                cropImage(geometry: geometry)
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(25)
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Prevent any default selection behavior
    }
    
    private func calculateInitialImageSize(in geometry: GeometryProxy) {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = geometry.size.width / geometry.size.height
        
        if imageAspect > containerAspect {
            // Image is wider - fit by height
            imageSize = CGSize(
                width: geometry.size.height * imageAspect,
                height: geometry.size.height
            )
        } else {
            // Image is taller - fit by width
            imageSize = CGSize(
                width: geometry.size.width,
                height: geometry.size.width / imageAspect
            )
        }
        
        // Set initial scale to ensure image covers crop area
        let minScaleForCrop = cropSize / min(imageSize.width, imageSize.height)
        if scale < minScaleForCrop {
            scale = minScaleForCrop * 1.1 // Add small buffer
        }
    }
    
    private func constrainedOffset(in geometry: GeometryProxy) -> CGSize {
        return calculateConstrainedOffset(offset, in: geometry)
    }
    
    private func calculateConstrainedOffset(_ proposedOffset: CGSize, in geometry: GeometryProxy) -> CGSize {
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        // Calculate the maximum offset that keeps the crop area within the image
        let maxOffsetX = max(0, (scaledImageSize.width - cropSize) / 2)
        let maxOffsetY = max(0, (scaledImageSize.height - cropSize) / 2)
        
        let constrainedX = max(-maxOffsetX, min(maxOffsetX, proposedOffset.width))
        let constrainedY = max(-maxOffsetY, min(maxOffsetY, proposedOffset.height))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
    
    private func cropOverlay() -> some View {
        ZStack {
            // Dark overlay with circular cutout
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .mask(
                    Rectangle()
                        .overlay(
                            Circle()
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        )
                )
                .ignoresSafeArea()
            
            // Crop circle border
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
            
            // Inner guide circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: cropSize - 20, height: cropSize - 20)
        }
    }
    
    private func cropImage(geometry: GeometryProxy) {
        // Calculate the actual crop area in image coordinates
        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        // Convert screen coordinates to image coordinates
        let imageRect = CGRect(
            x: centerX - scaledImageSize.width / 2 + offset.width,
            y: centerY - scaledImageSize.height / 2 + offset.height,
            width: scaledImageSize.width,
            height: scaledImageSize.height
        )
        
        let cropRect = CGRect(
            x: centerX - cropSize / 2,
            y: centerY - cropSize / 2,
            width: cropSize,
            height: cropSize
        )
        
        // Calculate crop area relative to image
        let relativeX = (cropRect.minX - imageRect.minX) / scaledImageSize.width
        let relativeY = (cropRect.minY - imageRect.minY) / scaledImageSize.height
        let relativeWidth = cropSize / scaledImageSize.width
        let relativeHeight = cropSize / scaledImageSize.height
        
        let finalCropRect = CGRect(
            x: relativeX * image.size.width,
            y: relativeY * image.size.height,
            width: relativeWidth * image.size.width,
            height: relativeHeight * image.size.height
        )
        
        // Crop the original image
        if let cgImage = image.cgImage?.cropping(to: finalCropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            // Create circular version
            let circularImage = createCircularImage(from: croppedImage)
            onCrop(circularImage)
        } else {
            // Fallback
            let resizedImage = resizeImageToCircle(image: image, size: cropSize)
            onCrop(resizedImage)
        }
    }
    
    private func createCircularImage(from image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        let path = UIBezierPath(ovalIn: rect)
        path.addClip()
        
        let drawRect = CGRect(
            x: (size - image.size.width) / 2,
            y: (size - image.size.height) / 2,
            width: image.size.width,
            height: image.size.height
        )
        image.draw(in: drawRect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func resizeImageToCircle(image: UIImage, size: CGFloat) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        let path = UIBezierPath(ovalIn: rect)
        path.addClip()
        
        image.draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

#Preview {
    PhotoCropView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        onCrop: { _ in },
        onCancel: { }
    )
}
