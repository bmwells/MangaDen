import SwiftUI
import PhotosUI

struct ReaderView: View {
    let chapter: Chapter
    let readingDirection: ReadingDirection
    @EnvironmentObject private var tabBarManager: TabBarManager
    @StateObject private var readerJava = ReaderViewJava()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPageIndex: Int = 0
    @State private var showNavigationBars: Bool = true
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isZooming: Bool = false
    @State private var showDownloadAlert = false
    @State private var downloadAlertMessage = ""
    @State private var loadedImages: [UIImage] = []
    @State private var isLoadingFromStorage = false
    
    var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if isLoadingFromStorage && isDownloaded {
                ProgressView("Loading from storage...")
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            } else if readerJava.isLoading && !isDownloaded {
                ProgressView("Loading chapter...")
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            } else if let error = readerJava.error, !isDownloaded {
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
            } else if loadedImages.isEmpty && readerJava.images.isEmpty {
                VStack {
                    Text("No Content")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("Unable to load chapter content")
                        .foregroundColor(.secondary)
                }
            } else {
                ZStack {
                    // Seamless scroll view for pages
                    let images = isDownloaded ? loadedImages : readerJava.images
                    if !images.isEmpty {
                        GeometryReader { geometry in
                            TrackableScrollView(currentIndex: $currentPageIndex) {
                                LazyHStack(spacing: 0) {
                                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                        SinglePageView(
                                            image: image,
                                            zoomScale: $zoomScale,
                                            lastZoomScale: $lastZoomScale,
                                            isZooming: $isZooming,
                                            isActive: index == currentPageIndex
                                        )
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .id(index)
                                    }
                                }
                            }
                            .disabled(isZooming)
                        }
                    }
                    
                    // Overlay tap areas for navigation (only when not zooming)
                    if !isZooming {
                        HStack(spacing: 0) {
                            // Left tap area (33%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .left)
                                }
                                .frame(maxWidth: .infinity)
                            
                            // Center tap area (34%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .center)
                                }
                                .frame(maxWidth: .infinity)
                            
                            // Right tap area (33%)
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTapGesture(location: .right)
                                }
                                .frame(maxWidth: .infinity)
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
                        let images = isDownloaded ? loadedImages : readerJava.images
                        Text("\(currentPageIndex + 1)/\(images.count)")
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
        .onAppear {
            if isDownloaded {
                loadFromStorage()
            } else {
                loadChapter()
            }
            // Force hide with a small delay to ensure the view is fully presented
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tabBarManager.isTabBarHidden = true
                print("ReaderView appeared - Tab bar hidden: \(tabBarManager.isTabBarHidden)")
            }
            
            // Mark chapter as read when opened
            markChapterAsRead()
        }
        .onDisappear {
            if !isDownloaded {
                readerJava.clearCache()
            }
            // Force show with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tabBarManager.isTabBarHidden = true
                print("ReaderView disappeared - Tab bar hidden: \(tabBarManager.isTabBarHidden)")
            }
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
    
    private func loadFromStorage() {
        isLoadingFromStorage = true
        let chapterId = chapter.id.uuidString
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            isLoadingFromStorage = false
            return
        }
        
        let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapterId)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var images: [UIImage] = []
            
            // Load images from directory
            do {
                let files = try fileManager.contentsOfDirectory(at: chapterDirectory, includingPropertiesForKeys: nil)
                let imageFiles = files.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                for imageFile in imageFiles {
                    if let imageData = try? Data(contentsOf: imageFile),
                       let image = UIImage(data: imageData) {
                        images.append(image)
                    }
                }
                
                DispatchQueue.main.async {
                    self.loadedImages = images
                    self.isLoadingFromStorage = false
                }
            } catch {
                print("Error loading chapter from storage: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingFromStorage = false
                }
            }
        }
    }
    
    private func markChapterAsRead() {
        // Notify that chapter has been read
        NotificationCenter.default.post(
            name: .chapterReadStatusChanged,
            object: nil,
            userInfo: ["chapterId": chapter.id]
        )
    }
    
    private func downloadCurrentImage() {
        let images = isDownloaded ? loadedImages : readerJava.images
        guard images.indices.contains(currentPageIndex) else {
            downloadAlertMessage = "No image available to download"
            showDownloadAlert = true
            return
        }
        
        let image = images[currentPageIndex]
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
        let images = isDownloaded ? loadedImages : readerJava.images
        guard currentPageIndex < images.count - 1 else { return }
        currentPageIndex += 1
        resetZoom()
    }
    
    private func navigateToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
        resetZoom()
    }
    
    private func resetZoom() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        isZooming = false
    }
}

// Updated TrackableScrollView with ScrollViewReader
struct TrackableScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content
    @Binding var currentIndex: Int
    
    @State private var contentOffset: CGFloat = 0
    @State private var scrollViewSize: CGSize = .zero
    @State private var scrollViewProxy: ScrollViewProxy?
    
    init(_ axes: Axis.Set = .horizontal,
         showsIndicators: Bool = false,
         currentIndex: Binding<Int>,
         @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self._currentIndex = currentIndex
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { outerGeometry in
            ScrollViewReader { proxy in
                ScrollView(axes, showsIndicators: showsIndicators) {
                    content
                        .background(
                            GeometryReader { innerGeometry in
                                Color.clear
                                    .onAppear {
                                        scrollViewSize = outerGeometry.size
                                        scrollViewProxy = proxy
                                    }
                                    .onChange(of: innerGeometry.frame(in: .named("scrollView")).minX) { oldValue, newValue in
                                        contentOffset = -newValue
                                        updateCurrentIndex(containerWidth: outerGeometry.size.width)
                                    }
                            }
                        )
                }
                .coordinateSpace(name: "scrollView")
                .onAppear {
                    scrollViewSize = outerGeometry.size
                    scrollViewProxy = proxy
                    // Scroll to initial page
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
                .onChange(of: outerGeometry.size) { oldSize, newSize in
                    scrollViewSize = newSize
                }
                .onChange(of: currentIndex) { oldValue, newValue in
                    // Only scroll when the index changes programmatically (from taps/swipes)
                    // Not when it changes from scrolling
                    let isFromScroll = abs(contentOffset - CGFloat(newValue) * outerGeometry.size.width) < outerGeometry.size.width / 2
                    
                    if !isFromScroll {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    private func updateCurrentIndex(containerWidth: CGFloat) {
        guard containerWidth > 0 else { return }
        
        let newIndex = Int(round(contentOffset / containerWidth))
        if newIndex != currentIndex && newIndex >= 0 {
            currentIndex = newIndex
        }
    }
}

struct SinglePageView: View {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var isZooming: Bool
    let isActive: Bool
    
    var body: some View {
        ZoomableImageView(
            image: image,
            zoomScale: $zoomScale,
            lastZoomScale: $lastZoomScale,
            isZooming: $isZooming,
            isActive: isActive
        )
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var isZooming: Bool
    let isActive: Bool
    
    @State private var offset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(isActive ? zoomScale : 1.0)
                .offset(x: isActive ? offset.width : 0, y: isActive ? offset.height : 0)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black)
                .clipped()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard isActive else { return }
                            
                            let delta = value / lastZoomScale
                            lastZoomScale = value
                            
                            // Calculate new zoom scale with bounds
                            let newScale = zoomScale * delta
                            zoomScale = min(max(newScale, 1.0), 5.0)
                            
                            isZooming = zoomScale > 1.0
                        }
                        .onEnded { _ in
                            guard isActive else { return }
                            
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
                            guard isActive && isZooming else { return }
                            
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
                            guard isActive else { return }
                            
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

enum TapLocation {
    case left, center, right
}
