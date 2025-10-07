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
    
    // Computed property for scrollbar progress
    private var scrollbarProgress: CGFloat {
        guard displayImages.count > 1 else { return 0 }
        
        if readingDirection == .rightToLeft {
            // For RTL: progress goes from 0.0 (first page) to 1.0 (last page)
            // This ensures circle starts on right for page 1
            return 1.0 - (CGFloat(currentPageIndex) / CGFloat(displayImages.count - 1))
        } else {
            // For LTR: progress goes from 0.0 (first page) to 1.0 (last page)
            return CGFloat(currentPageIndex) / CGFloat(displayImages.count - 1)
        }
    }
    
    var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mainContent
            
            // Bottom Scrollbar
            if showNavigationBars && !displayImages.isEmpty && !isZooming {
                VStack {
                    Spacer()
                    BottomScrollbar(
                        progress: scrollbarProgress,
                        readingDirection: readingDirection,
                        onTap: { location in
                            handleScrollbarTap(location: location)
                        },
                        onCenterTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNavigationBars.toggle()
                            }
                        },
                        onDrag: { progress in
                            handleScrollbarDrag(progress: progress)
                        }
                    )
                    .padding(.bottom, 8)
                }
            }
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
    
    // MARK: - Scrollbar Handling
    
    private func handleScrollbarTap(location: CGFloat) {
        guard !displayImages.isEmpty else { return }
        
        let targetPageIndex = Int(round(location * CGFloat(displayImages.count - 1)))
        let clampedIndex = max(0, min(displayImages.count - 1, targetPageIndex))
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPageIndex = clampedIndex
        }
    }
    
    private func handleScrollbarDrag(progress: CGFloat) {
        guard !displayImages.isEmpty else { return }
        
        let targetPageIndex = Int(round(progress * CGFloat(displayImages.count - 1)))
        let clampedIndex = max(0, min(displayImages.count - 1, targetPageIndex))
        
        currentPageIndex = clampedIndex
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 min timeout
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

// MARK: - Bottom Scrollbar Component
struct BottomScrollbar: View {
    let progress: CGFloat
    let readingDirection: ReadingDirection
    let onTap: (CGFloat) -> Void
    let onCenterTap: () -> Void
    let onDrag: (CGFloat) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Center tap area for hiding navigation - only active when not dragging
                if !isDragging {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onCenterTap()
                        }
                        .zIndex(0)
                }
                
                // Background scrollbar line - fixed width of 300px
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 300, height: 12)
                    .zIndex(1)
                
                // Progress fill - blue portion of the line
                if progress > 0 {
                    Capsule()
                        .fill(Color.blue)
                        .frame(
                            width: calculateProgressWidth(width: 300),
                            height: 12
                        )
                        .position(
                            x: calculateProgressPosition(width: 300),
                            y: geometry.size.height / 2
                        )
                        .zIndex(2)
                }
                
                // Scrollbar line tap area
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 300, height: 12)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let tapLocation = location.x
                        let tapProgress = calculateProgressFromPosition(position: tapLocation, width: 300)
                        onTap(tapProgress)
                    }
                    .zIndex(3) // Tap area above everything
                
                // Progress circle - draggable (placed above everything)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                    .position(
                        x: calculateCirclePosition(width: 300),
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let dragLocation = value.location.x
                                let dragProgress = calculateProgressFromPosition(position: dragLocation, width: 300)
                                onDrag(dragProgress)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isDragging)
                    .zIndex(4) // Circle above everything
            }
            .frame(width: 300)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: 30)
        .padding(.horizontal, 20)
    }
    
    private func calculateCirclePosition(width: CGFloat) -> CGFloat {
        let circlePosition: CGFloat
        
        if readingDirection == .rightToLeft {
            // For RTL: circle starts on right (progress 0.0), moves left to progress 1.0
            circlePosition = width - (progress * width)
        } else {
            // For LTR: circle starts on left (progress 0.0), moves right to progress 1.0
            circlePosition = progress * width
        }
        
        return max(15, min(width - 15, circlePosition)) // Adjusted for larger circle
    }
    
    private func calculateProgressWidth(width: CGFloat) -> CGFloat {
        return progress * width
    }
    
    private func calculateProgressPosition(width: CGFloat) -> CGFloat {
        if readingDirection == .rightToLeft {
            // For RTL: blue fill extends from right to left
            return width - (progress * width / 2)
        } else {
            // For LTR: blue fill extends from left to right
            return (progress * width) / 2
        }
    }
    
    private func calculateProgressFromPosition(position: CGFloat, width: CGFloat) -> CGFloat {
        let clampedPosition = max(15, min(width - 15, position)) // Adjusted for larger circle
        let progress: CGFloat
        
        if readingDirection == .rightToLeft {
            // For RTL: right side is progress 0.0, left side is progress 1.0
            progress = clampedPosition / width
        } else {
            // For LTR: left side is progress 0.0, right side is progress 1.0
            progress = clampedPosition / width
        }
        
        return max(0, min(1, progress))
    }
}

// MARK: - Supporting Views

struct TrackableScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content
    @Binding var currentIndex: Int
    
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
        GeometryReader { geometry in
            ScrollView(axes, showsIndicators: showsIndicators) {
                content
            }
            .scrollTargetLayout()
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(
                get: { currentIndex },
                set: { newValue in
                    if let newValue = newValue {
                        currentIndex = newValue
                    }
                }
            ))
            .onAppear {
                // Ensure initial scroll position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    currentIndex = currentIndex // This will trigger scroll to position
                }
            }
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
        .drawingGroup() // Add this for better rendering performance
        .allowsHitTesting(isActive) // Only allow interaction with active page
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

#Preview {
    ContentView()
}
