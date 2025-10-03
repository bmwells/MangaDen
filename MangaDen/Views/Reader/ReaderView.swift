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
    @State private var isChapterReady = false
    @State private var downloadProgress: String = ""
    
    // Computed property to get images in correct order based on reading direction
    private var displayImages: [UIImage] {
        let images = isDownloaded ? loadedImages : readerJava.images
        if readingDirection == .rightToLeft {
            return images.reversed()
        }
        return images
    }
    
    // Computed property for displayed page number
    private var displayedPageNumber: Int {
        if readingDirection == .rightToLeft {
            let totalPages = displayImages.count
            return totalPages - currentPageIndex
        } else {
            return currentPageIndex + 1
        }
    }
    
    var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mainContent
        }
        .navigationBarBackButtonHidden(true) // Hide the default back button
        .toolbar(content: toolbarContent)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavigationBars)
        .onAppear { onAppearAction() }
        .onDisappear { onDisappearAction() }
        .statusBar(hidden: !showNavigationBars)
        .animation(.easeInOut(duration: 0.2), value: currentPageIndex)
        .animation(.easeInOut(duration: 0.2), value: showNavigationBars)
        .alert("Download", isPresented: $showDownloadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(downloadAlertMessage)
        }
        .onChange(of: readerJava.images) { oldValue, newValue in
            handleImagesChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: loadedImages) { oldValue, newValue in
            handleLoadedImagesChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: readerJava.downloadProgress) { oldValue, newValue in
            updateDownloadProgress(progress: newValue)
        }
    }
    
    // MARK: - Main Content Views
    
    @ViewBuilder
    private var mainContent: some View {
        if !isChapterReady {
            loadingView
        } else {
            contentView
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading chapter...")
                .font(.headline)
                .foregroundColor(.white)
            
            if !downloadProgress.isEmpty {
                Text(downloadProgress)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: downloadProgress)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoadingFromStorage && isDownloaded {
            storageLoadingView
        } else if readerJava.isLoading && !isDownloaded {
            onlineLoadingView
        } else if let error = readerJava.error, !isDownloaded {
            errorView(error: error)
        } else if displayImages.isEmpty {
            emptyContentView
        } else {
            readerContentView
        }
    }
    
    private var storageLoadingView: some View {
        ProgressView("Loading from storage...")
            .scaleEffect(1.5)
            .foregroundColor(.white)
    }
    
    private var onlineLoadingView: some View {
        ProgressView("Loading chapter...")
            .scaleEffect(1.5)
            .foregroundColor(.white)
    }
    
    private func errorView(error: String) -> some View {
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
    }
    
    private var emptyContentView: some View {
        VStack {
            Text("No Content")
                .font(.title)
                .foregroundColor(.gray)
            
            Text("Unable to load chapter content")
                .foregroundColor(.secondary)
        }
    }
    
    private var readerContentView: some View {
        ZStack {
            GeometryReader { geometry in
                TrackableScrollView(currentIndex: $currentPageIndex) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(displayImages.enumerated()), id: \.offset) { index, image in
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
            
            if !isZooming {
                navigationOverlay
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { handleSwipeGesture(value: $0) }
        )
    }
    
    private var navigationOverlay: some View {
        HStack(spacing: 0) {
            tapArea(location: .left)
            tapArea(location: .center)
            tapArea(location: .right)
        }
    }
    
    private func tapArea(location: TapLocation) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                handleTapGesture(location: location)
            }
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if showNavigationBars {
                backButton
            }
        }
        
        ToolbarItem(placement: .principal) {
            if showNavigationBars {
                titleView
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if showNavigationBars {
                downloadButton
            }
        }
    }
    
    // Custom Back Button
    private var backButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "chevron.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
        }
    }
    
    private var titleView: some View {
        VStack {
            Text("Chapter \(chapter.formattedChapterNumber)")
                .font(.headline)
                .foregroundColor(.white)
            Text("\(displayedPageNumber)/\(displayImages.count)")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    // Download Button
    private var downloadButton: some View {
        Button(action: downloadCurrentImage) {
            Image(systemName: "square.and.arrow.down")
                .font(.title3)
                .foregroundColor(.white)
                .padding(8)
        }
    }
    
    // MARK: - Actions
    
    private func onAppearAction() {
        if isDownloaded {
            loadFromStorage()
        } else {
            loadChapter()
        }
        
        tabBarManager.isTabBarHidden = true
        markChapterAsRead()
    }
    
    private func onDisappearAction() {
        if !isDownloaded {
            readerJava.clearCache()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tabBarManager.isTabBarHidden = true
        }
    }
    
    private func loadChapter() {
        guard let url = URL(string: chapter.url) else {
            readerJava.error = "Invalid chapter URL"
            isChapterReady = true
            return
        }
        
        readerJava.loadChapter(url: url)
        
        // Set a timeout to ensure we don't get stuck in loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { // 60 second timeout
            if !isChapterReady && readerJava.images.isEmpty && readerJava.error == nil {
                readerJava.error = "Loading timeout - please check your connection"
                isChapterReady = true
            }
        }
    }
    
    private func loadFromStorage() {
        isLoadingFromStorage = true
        let chapterId = chapter.id.uuidString
        let fileManager = FileManager.default
        
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            isLoadingFromStorage = false
            isChapterReady = true
            return
        }
        
        let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapterId)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            var images: [UIImage] = []
            
            do {
                let files = try fileManager.contentsOfDirectory(at: chapterDirectory, includingPropertiesForKeys: nil)
                let imageFiles = files
                    .filter { $0.pathExtension == "jpg" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                
                for imageFile in imageFiles {
                    if let imageData = try? Data(contentsOf: imageFile),
                       let image = UIImage(data: imageData) {
                        images.append(image)
                    }
                }
                
                DispatchQueue.main.async {
                    self.loadedImages = images
                    self.isLoadingFromStorage = false
                    
                    // Set initial page based on reading direction for downloaded chapters
                    if self.readingDirection == .rightToLeft && !images.isEmpty {
                        // For RTL downloaded chapters, start at the last page index
                        // This will become the "first" page when displayImages reverses the array
                        self.currentPageIndex = images.count - 1
                        print("RTL Downloaded: Set initial page to \(self.currentPageIndex) for \(images.count) images")
                    } else if !images.isEmpty {
                        // For LTR downloaded chapters, start at the first page
                        self.currentPageIndex = 0
                        print("LTR Downloaded: Set initial page to 0 for \(images.count) images")
                    }
                    
                    // Images are loaded, mark as ready
                    self.isChapterReady = true
                    
                    print("Loaded \(images.count) images from storage")
                }
            } catch {
                print("Error loading chapter from storage: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingFromStorage = false
                    self.isChapterReady = true
                }
            }
        }
    }
    
    private func markChapterAsRead() {
        NotificationCenter.default.post(
            name: .chapterReadStatusChanged,
            object: nil,
            userInfo: ["chapterId": chapter.id]
        )
    }
    
    private func downloadCurrentImage() {
        guard displayImages.indices.contains(currentPageIndex) else {
            downloadAlertMessage = "No image available to download"
            showDownloadAlert = true
            return
        }
        
        let image = displayImages[currentPageIndex]
        saveImageToPhotos(image)
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            downloadAlertMessage = "Image saved to Photos!"
            showDownloadAlert = true
            
        case .notDetermined:
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
            navigateToPreviousPage()
        case .center:
            withAnimation(.easeInOut(duration: 0.2)) {
                showNavigationBars.toggle()
            }
        case .right:
            navigateToNextPage()
        }
    }
    
    private func handleSwipeGesture(value: DragGesture.Value) {
        guard !isZooming else { return }
        
        let horizontalAmount = value.translation.width
        
        if horizontalAmount < -50 {
            if readingDirection == .leftToRight {
                navigateToNextPage()
            } else {
                navigateToPreviousPage()
            }
        } else if horizontalAmount > 50 {
            if readingDirection == .leftToRight {
                navigateToPreviousPage()
            } else {
                navigateToNextPage()
            }
        }
    }
    
    private func navigateToNextPage() {
        guard currentPageIndex < displayImages.count - 1 else { return }
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
    
    // MARK: - Helper Methods
    
    private func updateDownloadProgress(progress: String) {
        DispatchQueue.main.async {
            self.downloadProgress = progress
        }
    }
    
    private func handleImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        // For non-downloaded chapters only
        if !isDownloaded {
            let imagesNowLoaded = !newValue.isEmpty
            
            if imagesNowLoaded {
                // Set initial page based on reading direction for non-downloaded chapters
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.readingDirection == .rightToLeft && !newValue.isEmpty {
                        // For non-downloaded RTL, we need to start at the last original image
                        self.currentPageIndex = newValue.count - 1
                        print("RTL Online: Set initial page to \(self.currentPageIndex) for \(newValue.count) images")
                    } else {
                        self.currentPageIndex = 0
                        print("LTR Online: Set initial page to 0 for \(newValue.count) images")
                    }
                    self.isChapterReady = true
                    // Clear download progress when chapter is ready
                    self.downloadProgress = ""
                }
            }
        }
    }
    
    private func handleLoadedImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        // For downloaded chapters
        if isDownloaded && !newValue.isEmpty {
            // Set initial page based on reading direction for downloaded chapters
            if readingDirection == .rightToLeft {
                currentPageIndex = newValue.count - 1
                print("RTL Downloaded (onChange): Set initial page to \(currentPageIndex) for \(newValue.count) images")
            } else {
                currentPageIndex = 0
                print("LTR Downloaded (onChange): Set initial page to 0 for \(newValue.count) images")
            }
            isChapterReady = true
        }
    }
}

// MARK: - Supporting Views

struct TrackableScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content
    @Binding var currentIndex: Int
    
    @State private var contentOffset: CGFloat = 0
    @State private var scrollViewSize: CGSize = .zero
    
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
                .gesture(magnificationGesture)
                .simultaneousGesture(dragGesture(geometry: geometry))
                .simultaneousGesture(doubleTapGesture)
        }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard isActive else { return }
                
                let delta = value / lastZoomScale
                lastZoomScale = value
                
                let newScale = zoomScale * delta
                zoomScale = min(max(newScale, 1.0), 5.0)
                
                isZooming = zoomScale > 1.0
            }
            .onEnded { _ in
                guard isActive else { return }
                
                lastZoomScale = 1.0
                
                if zoomScale < 1.0 {
                    withAnimation {
                        zoomScale = 1.0
                        offset = .zero
                        isZooming = false
                    }
                }
            }
    }
    
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard isActive && isZooming else { return }
                
                let maxOffsetX = (image.size.width * zoomScale - geometry.size.width) / 2
                let maxOffsetY = (image.size.height * zoomScale - geometry.size.height) / 2
                
                let newOffset = CGSize(
                    width: offset.width + value.translation.width,
                    height: offset.height + value.translation.height
                )
                
                offset = CGSize(
                    width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                    height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                )
            }
    }
    
    private var doubleTapGesture: some Gesture {
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
    }
}

enum TapLocation {
    case left, center, right
}
