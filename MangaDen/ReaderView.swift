import SwiftUI
import PhotosUI

struct ReaderView: View {
    let chapter: Chapter
    let readingDirection: ReadingDirection
    @StateObject private var readerJava = ReaderViewJava()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPageIndex: Int = 0
    @State private var showNavigationBars: Bool = true
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isZooming: Bool = false
    @State private var showDownloadAlert = false
    @State private var downloadAlertMessage = ""
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            if readerJava.isLoading {
                ProgressView("Loading chapter...")
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            } else if let error = readerJava.error {
                VStack {
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Retry") {
                        loadChapter()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if readerJava.images.isEmpty {
                VStack {
                    Text("No Content")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("Unable to load chapter content")
                        .foregroundColor(.secondary)
                }
            } else {
                ZStack {
                    // Main image viewer - Use ZStack instead of TabView for manual control
                    if readerJava.images.indices.contains(currentPageIndex) {
                        ZoomableImageView(
                            image: readerJava.images[currentPageIndex],
                            zoomScale: $zoomScale,
                            lastZoomScale: $lastZoomScale,
                            isZooming: $isZooming
                        )
                        .transition(.opacity)
                    }
                    
                    // Tap areas for navigation
                    if !isZooming {
                        HStack(spacing: 0) {
                            // Left tap area (20%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .left)
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.2)
                            
                            // Center tap area (60%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .center)
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.6)
                            
                            // Right tap area (20%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .right)
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.2)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            handleSwipeGesture(value: value)
                        }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavigationBars)
        .toolbar {
            if showNavigationBars {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Chapter \(chapter.formattedChapterNumber)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(currentPageIndex + 1)/\(readerJava.images.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        downloadCurrentImage()
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                }
            }
        }
        .hideTabBar()
        .onAppear {
            loadChapter()
        }
        .onDisappear {
            readerJava.clearCache()
        }
        .statusBar(hidden: !showNavigationBars)
        .animation(.easeInOut(duration: 0.2), value: currentPageIndex)
        .animation(.easeInOut(duration: 0.2), value: showNavigationBars)
        .alert("Download", isPresented: $showDownloadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(downloadAlertMessage)
        }
    }
    
    private func loadChapter() {
        guard let url = URL(string: chapter.url) else {
            readerJava.error = "Invalid chapter URL"
            return
        }
        
        readerJava.loadChapter(url: url)
    }
    
    private func downloadCurrentImage() {
        guard readerJava.images.indices.contains(currentPageIndex) else {
            downloadAlertMessage = "No image available to download"
            showDownloadAlert = true
            return
        }
        
        let image = readerJava.images[currentPageIndex]
        saveImageToPhotos(image)
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        // Check photo library authorization status
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            // Already authorized, save the image
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            downloadAlertMessage = "Image saved to Photos!"
            showDownloadAlert = true
            
        case .notDetermined:
            // Request authorization
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        self.downloadAlertMessage = "Image saved to Photos!"
                        self.showDownloadAlert = true
                    } else {
                        self.downloadAlertMessage = "Photo library access denied. Please enable it in Settings."
                        self.showDownloadAlert = true
                    }
                }
            }
            
        case .denied, .restricted:
            downloadAlertMessage = "Photo library access denied. Please enable it in Settings."
            showDownloadAlert = true
            
        @unknown default:
            downloadAlertMessage = "Unable to save image. Unknown error."
            showDownloadAlert = true
        }
    }
    
    private func handleTapGesture(location: TapLocation) {
        switch location {
        case .left:
            // Left side tap - depends on reading direction
            if readingDirection == .leftToRight {
                navigateToPreviousPage() // L→R: left tap = previous page
            } else {
                navigateToNextPage()    // L←R: left tap = next page
            }
        case .center:
            withAnimation(.easeInOut(duration: 0.2)) {
                showNavigationBars.toggle()
            }
        case .right:
            // Right side tap - depends on reading direction
            if readingDirection == .leftToRight {
                navigateToNextPage()    // L→R: right tap = next page
            } else {
                navigateToPreviousPage() // L←R: right tap = previous page
            }
        }
    }
    
    private func handleSwipeGesture(value: DragGesture.Value) {
        guard !isZooming else { return }
        
        let horizontalAmount = value.translation.width
        
        if horizontalAmount < -50 {
            // Swipe left
            if readingDirection == .leftToRight {
                navigateToNextPage()    // L→R: swipe left = next page
            } else {
                navigateToPreviousPage() // L←R: swipe left = previous page
            }
        } else if horizontalAmount > 50 {
            // Swipe right
            if readingDirection == .leftToRight {
                navigateToPreviousPage() // L→R: swipe right = previous page
            } else {
                navigateToNextPage()    // L←R: swipe right = next page
            }
        }
    }
    
    private func navigateToNextPage() {
        guard currentPageIndex < readerJava.images.count - 1 else { return }
        withAnimation {
            currentPageIndex += 1
            resetZoom()
        }
    }
    
    private func navigateToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        withAnimation {
            currentPageIndex -= 1
            resetZoom()
        }
    }
    
    private func resetZoom() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        isZooming = false
    }
}

enum TapLocation {
    case left, center, right
}

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var isZooming: Bool
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoomScale)
                .offset(x: offset.width, y: offset.height)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black)
                .clipped()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastZoomScale
                            lastZoomScale = value
                            
                            // Calculate new zoom scale with bounds
                            let newScale = zoomScale * delta
                            zoomScale = min(max(newScale, 1.0), 5.0)
                            
                            isZooming = zoomScale > 1.0
                        }
                        .onEnded { _ in
                            lastZoomScale = 1.0
                            
                            // Snap back to min/max if needed
                            if zoomScale < 1.0 {
                                withAnimation {
                                    zoomScale = 1.0
                                    offset = .zero
                                    isZooming = false
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard isZooming else { return }
                            
                            let maxOffsetX = (image.size.width * zoomScale - geometry.size.width) / 2
                            let maxOffsetY = (image.size.height * zoomScale - geometry.size.height) / 2
                            
                            let newOffset = CGSize(
                                width: offset.width + value.translation.width,
                                height: offset.height + value.translation.height
                            )
                            
                            // Apply bounds to offset
                            offset = CGSize(
                                width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                            )
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if zoomScale > 1.0 {
                                    zoomScale = 1.0
                                    offset = .zero
                                    isZooming = false
                                } else {
                                    zoomScale = 2.0
                                    isZooming = true
                                }
                                lastZoomScale = zoomScale
                            }
                        }
                )
        }
    }
}



#Preview {
    ContentView()
}
