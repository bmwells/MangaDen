import SwiftUI
import PhotosUI

struct ReaderView: View {
    let chapter: Chapter
    let readingDirection: ReadingDirection
    let titleID: UUID
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
    @State private var originalImages: [UIImage] = []
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasRestoredFromBookmark = false
    
    
    // Computed property to get images in correct order based on reading direction
    private var displayImages: [UIImage] {
        if readingDirection == .rightToLeft {
            return originalImages.reversed()
        }
        return originalImages
    }
    
    // Computed property for displayed page number
    private var displayedPageNumber: Int {
        let totalPages = displayImages.count
        guard totalPages > 0 else { return 0 }
        
        if readingDirection == .rightToLeft {
            // For RTL: When currentPageIndex = displayImages.count - 1 (last display), show Page 1
            // When currentPageIndex = 0 (first display), show Page totalPages
            let pageNumber = totalPages - currentPageIndex
            print("RTL Page Calc: currentPageIndex=\(currentPageIndex), totalPages=\(totalPages), result=\(pageNumber)")
            return pageNumber
        } else {
            // For LTR: currentPageIndex + 1 gives the actual page number
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
        chapter.safeIsDownloaded
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
        .onChange(of: currentPageIndex) { oldValue, newValue in
                    handlePageChange(oldValue: oldValue, newValue: newValue)
                }
    }
    
    // MARK: - Scrollbar Handling
    
    private func handleScrollbarTap(location: CGFloat) {
        guard !displayImages.isEmpty else { return }
        
        let targetPageIndex = Int(round(location * CGFloat(displayImages.count - 1)))
        let clampedIndex = max(0, min(displayImages.count - 1, targetPageIndex))
        
        print("Scrollbar tap: location=\(location), target=\(targetPageIndex), clamped=\(clampedIndex)")
        currentPageIndex = clampedIndex
        scrollToPage(currentPageIndex, animated: true)
    }
    
    private func handleScrollbarDrag(progress: CGFloat) {
        guard !displayImages.isEmpty else { return }
        
        let targetPageIndex = Int(round(progress * CGFloat(displayImages.count - 1)))
        let clampedIndex = max(0, min(displayImages.count - 1, targetPageIndex))
        
        print("Scrollbar drag: progress=\(progress), target=\(targetPageIndex), clamped=\(clampedIndex)")
        currentPageIndex = clampedIndex
        // Don't animate during drag for smooth tracking
        scrollToPage(currentPageIndex, animated: false)
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
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
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
                    .scrollTargetBehavior(.paging)
                    .onAppear {
                        scrollProxy = proxy
                        // Scroll to initial position after a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToPage(currentPageIndex, animated: false)
                        }
                    }
                    .onChange(of: currentPageIndex) { oldValue, newValue in
                        // Only scroll if the page actually changed and it's not from user scrolling
                        if oldValue != newValue {
                            scrollToPage(newValue, animated: true)
                        }
                    }
                }
            }
            .disabled(isZooming)
            
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
                .onAppear {
                    print("Title View: displayedPageNumber=\(displayedPageNumber), displayImages.count=\(displayImages.count)")
                }
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
        // Reset the bookmark restoration flag
        hasRestoredFromBookmark = false
        
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
        // Save final bookmark state when leaving the reader
            updateBookmark()
        
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
                
                // FIX: Sort files by page number instead of just filename
                let imageFiles = files
                    .filter { $0.pathExtension == "jpg" }
                    .sorted { file1, file2 in
                        // Extract page numbers from filenames (e.g., "0.jpg", "1.jpg", etc.)
                        let page1 = Int(file1.deletingPathExtension().lastPathComponent) ?? 0
                        let page2 = Int(file2.deletingPathExtension().lastPathComponent) ?? 0
                        return page1 < page2
                    }
                
                print("Loading \(imageFiles.count) images from storage with order:")
                for (index, file) in imageFiles.enumerated() {
                    print("  Page \(index): \(file.lastPathComponent)")
                }
                
                for imageFile in imageFiles {
                    if let imageData = try? Data(contentsOf: imageFile),
                       let image = UIImage(data: imageData) {
                        images.append(image)
                    }
                }
                
                DispatchQueue.main.async {
                    self.originalImages = images
                    self.loadedImages = images
                    self.isLoadingFromStorage = false
                    
                    print("Loaded \(images.count) images from storage for downloaded chapter")
                    
                    // FIX: Set chapter ready FIRST, then set initial page
                    self.isChapterReady = true
                    
                    // Call setInitialPageIndex immediately after setting isChapterReady
                    // This ensures the UI is ready and images are loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.setInitialPageIndex()
                        print("Initial page set for downloaded chapter: \(self.currentPageIndex)")
                    }
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
        let newIndex = currentPageIndex + 1
        print("Next page: \(currentPageIndex) -> \(newIndex)")
        currentPageIndex = newIndex
        scrollToPage(currentPageIndex, animated: true)
        resetZoom()
    }
    
    private func navigateToPreviousPage() {
        guard currentPageIndex > 0 else { return }
        let newIndex = currentPageIndex - 1
        print("Previous page: \(currentPageIndex) -> \(newIndex)")
        currentPageIndex = newIndex
        scrollToPage(currentPageIndex, animated: true)
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
    
    // MARK: - Manual Scroll Methods
    
    private func scrollToPage(_ pageIndex: Int, animated: Bool) {
        print("Scrolling to page index: \(pageIndex)")
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(pageIndex, anchor: .center)
            }
        } else {
            scrollProxy?.scrollTo(pageIndex, anchor: .center)
        }
    }
    
    // NEW: Handle page changes for bookmark updates
        private func handlePageChange(oldValue: Int, newValue: Int) {
            // Only scroll if the page actually changed and it's not from user scrolling
            if oldValue != newValue {
                scrollToPage(newValue, animated: true)
            }
            
            // Update bookmark after a short delay to avoid excessive saves
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                updateBookmark()
            }
        }
        
        // MARK: - Bookmark Management
        
        // NEW: Update bookmark with current page
        private func updateBookmark() {
            // Only update bookmark if we have images loaded and we're not at the very beginning
            guard !displayImages.isEmpty else { return }
            
            // Convert current display index to actual page number
            let currentPage: Int
            if readingDirection == .rightToLeft {
                currentPage = displayImages.count - currentPageIndex
            } else {
                currentPage = currentPageIndex + 1
            }
            
            // Save bookmark to UserDefaults
            saveBookmarkToUserDefaults(currentPage: currentPage)
            
            print("Bookmark updated: Chapter \(chapter.formattedChapterNumber), Page \(currentPage)")
        }
        
        // NEW: Save bookmark using UserDefaults
        private func saveBookmarkToUserDefaults(currentPage: Int) {
            let bookmarkKey = "currentBookmark_\(titleID.uuidString)"
            let bookmarkData: [String: Any] = [
                "chapterId": chapter.id.uuidString,
                "chapterNumber": chapter.chapterNumber,
                "page": currentPage,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
            print("Bookmark saved to UserDefaults: Title \(titleID.uuidString), Chapter \(chapter.formattedChapterNumber), Page \(currentPage)")
            
            // Notify that bookmarks changed so TitleView can update
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
        }
        
    // NEW: Load bookmark from UserDefaults with better debugging
    private func loadBookmarkFromUserDefaults() -> Int? {
        let bookmarkKey = "currentBookmark_\(titleID.uuidString)"
        
        print("Checking for bookmark with key: \(bookmarkKey)")
        
        guard let bookmarkData = UserDefaults.standard.dictionary(forKey: bookmarkKey) else {
            print("No bookmark data found for key: \(bookmarkKey)")
            return nil
        }
        
        guard let savedChapterId = bookmarkData["chapterId"] as? String else {
            print("No chapterId found in bookmark data")
            return nil
        }
        
        guard let savedPage = bookmarkData["page"] as? Int else {
            print("No page found in bookmark data")
            return nil
        }
        
        print("Bookmark data - savedChapterId: \(savedChapterId), currentChapterId: \(chapter.id.uuidString)")
        
        // Check if this bookmark is for the current chapter
        if savedChapterId == chapter.id.uuidString {
            print("Bookmark found for current chapter: Chapter \(chapter.formattedChapterNumber), Page \(savedPage)")
            return savedPage
        } else {
            print("Bookmark exists but for different chapter: \(savedChapterId) vs current: \(chapter.id.uuidString)")
            return nil
        }
    }
    
    
    // MARK: - Initial Page Setup
            
    private func setInitialPageIndex() {
        guard !displayImages.isEmpty else {
            print("No display images available for setting initial page")
            return
        }
        
        print("Setting initial page index for \(displayImages.count) images")
        print("Reading direction: \(readingDirection)")
        print("Chapter is downloaded: \(isDownloaded)")
        print("hasRestoredFromBookmark: \(hasRestoredFromBookmark)")
        
        // Check if we have a bookmarked page for this chapter
        if let bookmarkedPage = loadBookmarkFromUserDefaults(), !hasRestoredFromBookmark {
            print("Attempting to restore from bookmark: page \(bookmarkedPage)")
            
            // Convert bookmarked page to display index
            let targetIndex: Int
            if readingDirection == .rightToLeft {
                // For RTL: bookmarkedPage 1 corresponds to display index displayImages.count - 1
                targetIndex = displayImages.count - bookmarkedPage
                print("RTL conversion: bookmarkedPage \(bookmarkedPage) -> targetIndex \(targetIndex)")
            } else {
                // For LTR: bookmarkedPage 1 corresponds to display index 0
                targetIndex = bookmarkedPage - 1
                print("LTR conversion: bookmarkedPage \(bookmarkedPage) -> targetIndex \(targetIndex)")
            }
            
            // Clamp the index to valid range
            let clampedIndex = max(0, min(displayImages.count - 1, targetIndex))
            currentPageIndex = clampedIndex
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.scrollToPage(self.currentPageIndex, animated: false)
                print("Scrolled to bookmarked page: \(self.currentPageIndex)")
            }
        } else {
            // Original logic for no bookmark
            if readingDirection == .rightToLeft {
                currentPageIndex = displayImages.count - 1
                print("RTL INIT: Set currentPageIndex to \(currentPageIndex) for Page 1")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.scrollToPage(self.currentPageIndex, animated: false)
                }
            } else {
                currentPageIndex = 0
                print("LTR: Set initial page to 0 for \(displayImages.count) display images")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.scrollToPage(self.currentPageIndex, animated: false)
                }
            }
        }
    }
    
    // MARK: - Modified Helper Methods
    
    private func handleImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        // For non-downloaded chapters only
        if !isDownloaded {
            let imagesNowLoaded = !newValue.isEmpty
            
            if imagesNowLoaded {
                print("Images loaded: \(newValue.count), setting chapter ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.originalImages = newValue
                    self.setInitialPageIndex()
                    self.isChapterReady = true
                    self.downloadProgress = ""
                    
                    // Also make sure the readerJava isLoading state is false
                    if self.readerJava.isLoading {
                        print("Forcing readerJava isLoading to false")
                        self.readerJava.isLoading = false
                    }
                }
            }
        }
    }
    
    private func handleLoadedImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        // For downloaded chapters
        if isDownloaded && !newValue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.originalImages = newValue
                self.setInitialPageIndex()
                self.isChapterReady = true
            }
        }
    }
    
    // Helper methods for debug
    private func displayIndexToOriginalIndex(_ displayIndex: Int) -> Int {
        if readingDirection == .rightToLeft {
            return originalImages.count - 1 - displayIndex
        }
        return displayIndex
    }
    
    private func displayedPageNumberForIndex(_ displayIndex: Int) -> Int {
        if readingDirection == .rightToLeft {
            return originalImages.count - displayIndex
        }
        return displayIndex + 1
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
