//
//  ReaderCoordinator.swift
//  MangaDen
//
//  Created by Brody Wells on 10/15/25.
//

import SwiftUI
import PhotosUI

@MainActor
class ReaderCoordinator: ObservableObject {
    
    // MARK: - Actions
    
    static func onAppearAction(
        isDownloaded: Bool,
        hasRestoredFromBookmark: Bool,
        tabBarManager: TabBarManager,
        loadFromStorage: @escaping () -> Void,
        loadChapter: @escaping () -> Void,
        markChapterAsRead: @escaping () -> Void
    ) {
        // Reset the bookmark restoration flag
        if isDownloaded {
            loadFromStorage()
        } else {
            loadChapter()
        }
        
        tabBarManager.isTabBarHidden = true
        markChapterAsRead()
    }
    
    static func onDisappearAction(
        isDownloaded: Bool,
        stopLoading: @escaping () -> Void,
        updateBookmark: @escaping () -> Void,
        tabBarManager: TabBarManager
    ) {
        stopLoading() // Stop WebView and extraction
        
        updateBookmark()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tabBarManager.isTabBarHidden = true
        }
    }
    
    static func loadChapter(
        chapter: Chapter,
        readerJava: ReaderViewJava,
        isChapterReady: Binding<Bool>
    ) {
        guard let url = URL(string: chapter.url) else {
            readerJava.error = "Invalid chapter URL"
            isChapterReady.wrappedValue = true
            return
        }
        
        readerJava.loadChapter(url: url)
        
        // Set a timeout to ensure we don't get stuck in loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak readerJava] in // 3 min wait before load timeout
            // Capture the current state values to avoid concurrency issues
            let currentIsChapterReady = isChapterReady.wrappedValue
            let currentImages = readerJava?.images ?? []
            let currentError = readerJava?.error
            
            if !currentIsChapterReady && currentImages.isEmpty && currentError == nil {
                readerJava?.error = "Loading timeout - please check your connection"
                isChapterReady.wrappedValue = true
            }
        }
    }
    
    static func loadFromStorage(
        chapter: Chapter,
        isLoadingFromStorage: Binding<Bool>,
        originalImages: Binding<[UIImage]>,
        loadedImages: Binding<[UIImage]>,
        isChapterReady: Binding<Bool>,
        setInitialPageIndex: @escaping () -> Void
    ) {
        isLoadingFromStorage.wrappedValue = true
        let chapterId = chapter.id.uuidString
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    isLoadingFromStorage.wrappedValue = false
                    isChapterReady.wrappedValue = true
                }
                return
            }
            
            let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapterId)")
            
            do {
                let files = try fileManager.contentsOfDirectory(at: chapterDirectory, includingPropertiesForKeys: nil)
                
                let imageFiles = files
                    .filter { $0.pathExtension == "jpg" }
                    .sorted { file1, file2 in
                        let page1 = Int(file1.deletingPathExtension().lastPathComponent) ?? 0
                        let page2 = Int(file2.deletingPathExtension().lastPathComponent) ?? 0
                        return page1 < page2
                    }
                
                var loadedImagesArray: [UIImage] = []
                for imageFile in imageFiles {
                    if let imageData = try? Data(contentsOf: imageFile),
                       let image = UIImage(data: imageData) {
                        loadedImagesArray.append(image)
                    }
                }
                
                // Create a local copy to avoid capturing the mutable array
                let finalImages = loadedImagesArray
                
                DispatchQueue.main.async {
                    originalImages.wrappedValue = finalImages
                    loadedImages.wrappedValue = finalImages
                    isLoadingFromStorage.wrappedValue = false
                                        
                    isChapterReady.wrappedValue = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        setInitialPageIndex()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingFromStorage.wrappedValue = false
                    isChapterReady.wrappedValue = true
                }
            }
        }
    }
    
    static func markChapterAsRead(chapter: Chapter, titleID: UUID) {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            // Load the current title using titleID, not chapter ID
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(titleID.uuidString).json")
            
            guard fileManager.fileExists(atPath: titleFile.path) else {
                print("Title file not found for title ID: \(titleID)")
                return
            }
            
            let titleData = try Data(contentsOf: titleFile)
            var title = try JSONDecoder().decode(Title.self, from: titleData)
            
            // Update the chapter's read status
            if let chapterIndex = title.chapters.firstIndex(where: { $0.id == chapter.id }) {
                title.chapters[chapterIndex].isRead = true
                
                // Save the updated title
                let updatedTitleData = try JSONEncoder().encode(title)
                try updatedTitleData.write(to: titleFile)
                
                NotificationCenter.default.post(name: .chapterReadStatusChanged, object: nil)
                NotificationCenter.default.post(name: .titleUpdated, object: nil)
            } else {
                print("Chapter not found in title: \(chapter.formattedChapterNumber)")
            }
        } catch {
            print("Error marking chapter as read: \(error)")
        }
    }
    
    static func downloadCurrentImage(
        displayImages: [UIImage],
        currentPageIndex: Int,
        downloadAlertMessage: Binding<String>,
        showDownloadAlert: Binding<Bool>
    ) {
        guard displayImages.indices.contains(currentPageIndex) else {
            downloadAlertMessage.wrappedValue = "No image available to download"
            showDownloadAlert.wrappedValue = true
            return
        }
        
        let image = displayImages[currentPageIndex]
        saveImageToPhotos(image, downloadAlertMessage: downloadAlertMessage, showDownloadAlert: showDownloadAlert)
    }
    
    static func saveImageToPhotos(
        _ image: UIImage,
        downloadAlertMessage: Binding<String>,
        showDownloadAlert: Binding<Bool>
    ) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            downloadAlertMessage.wrappedValue = "Image saved to Photos!"
            showDownloadAlert.wrappedValue = true
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        downloadAlertMessage.wrappedValue = "Image saved to Photos!"
                        showDownloadAlert.wrappedValue = true
                    } else {
                        downloadAlertMessage.wrappedValue = "Photo library access denied. Please enable it in Settings."
                        showDownloadAlert.wrappedValue = true
                    }
                }
            }
            
        case .denied, .restricted:
            downloadAlertMessage.wrappedValue = "Photo library access denied. Please enable it in Settings."
            showDownloadAlert.wrappedValue = true
            
        @unknown default:
            downloadAlertMessage.wrappedValue = "Unable to save image. Unknown error."
            showDownloadAlert.wrappedValue = true
        }
    }
    
    static func handleTapGesture(
        location: TapLocation,
        showNavigationBars: Binding<Bool>,
        isZooming: Bool,
        resetZoom: @escaping () -> Void,
        navigateToPreviousPage: @escaping () -> Void,
        navigateToNextPage: @escaping () -> Void
    ) {
        switch location {
        case .left:
            if !isZooming {
                navigateToPreviousPage()
            }
        case .center:
            withAnimation(.easeInOut(duration: 0.2)) {
                if isZooming {
                    resetZoom()
                }
                showNavigationBars.wrappedValue.toggle()
            }
        case .right:
            if !isZooming {
                navigateToNextPage()
            }
        }
    }
    
    static func handleSwipeGesture(
        value: DragGesture.Value,
        isZooming: Bool,
        navigateToPreviousPage: @escaping () -> Void,
        navigateToNextPage: @escaping () -> Void
    ) {
        guard !isZooming else { return }
        
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        guard abs(horizontalAmount) > abs(verticalAmount) else { return }
        
        let swipeThreshold: CGFloat = 50
        
        if horizontalAmount < -swipeThreshold {
            navigateToNextPage()
        } else if horizontalAmount > swipeThreshold {
            navigateToPreviousPage()
        }
    }
    
    static func navigateToNextPage(
        currentPageIndex: Binding<Int>,
        displayImages: [UIImage],
        scrollToPage: @escaping (Int, Bool) -> Void,
        resetZoom: @escaping () -> Void,
        checkForChapterNavigation: @escaping () -> Void
    ) {
        guard currentPageIndex.wrappedValue < displayImages.count - 1 else {
            // At last page, check for chapter navigation
            checkForChapterNavigation()
            return
        }
        let newIndex = currentPageIndex.wrappedValue + 1
        currentPageIndex.wrappedValue = newIndex
        scrollToPage(currentPageIndex.wrappedValue, true)
        resetZoom()
    }
    
    static func navigateToPreviousPage(
        currentPageIndex: Binding<Int>,
        displayImages: [UIImage],
        scrollToPage: @escaping (Int, Bool) -> Void,
        resetZoom: @escaping () -> Void,
        checkForChapterNavigation: @escaping () -> Void
    ) {
        guard currentPageIndex.wrappedValue > 0 else {
            // At first page, check for chapter navigation
            checkForChapterNavigation()
            return
        }
        let newIndex = currentPageIndex.wrappedValue - 1
        currentPageIndex.wrappedValue = newIndex
        scrollToPage(currentPageIndex.wrappedValue, true)
        resetZoom()
    }
    
    static func resetZoom(
        zoomScale: Binding<CGFloat>,
        lastZoomScale: Binding<CGFloat>,
        isZooming: Binding<Bool>
    ) {
        zoomScale.wrappedValue = 1.0
        lastZoomScale.wrappedValue = 1.0
        isZooming.wrappedValue = false
    }
    
    // MARK: - Helper Methods
    
    static func updateDownloadProgress(
        progress: String,
        downloadProgress: Binding<String>
    ) {
        DispatchQueue.main.async {
            downloadProgress.wrappedValue = progress
        }
    }
    
    // MARK: - Manual Scroll Methods
    
    static func scrollToPage(
        _ pageIndex: Int,
        animated: Bool,
        scrollProxy: ScrollViewProxy?
    ) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(pageIndex, anchor: .center)
            }
        } else {
            scrollProxy?.scrollTo(pageIndex, anchor: .center)
        }
    }
    
    static func handlePageChange(
        oldValue: Int,
        newValue: Int,
        scrollToPage: @escaping (Int, Bool) -> Void,
        updateBookmark: @escaping () -> Void
    ) {
        if oldValue != newValue {
            scrollToPage(newValue, true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateBookmark()
        }
    }
    
    // MARK: - Bookmark Management
    
    static func updateBookmark(
        displayImages: [UIImage],
        currentPageIndex: Int,
        readingDirection: ReadingDirection,
        chapter: Chapter,
        titleID: UUID
    ) {
        guard !displayImages.isEmpty else { return }
        
        let currentPage: Int
        if readingDirection == .rightToLeft {
            currentPage = displayImages.count - currentPageIndex
        } else {
            currentPage = currentPageIndex + 1
        }
        
        saveBookmarkToUserDefaults(currentPage: currentPage, chapter: chapter, titleID: titleID)
        
        }
    
    static func saveBookmarkToUserDefaults(currentPage: Int, chapter: Chapter, titleID: UUID) {
        let bookmarkKey = "currentBookmark_\(titleID.uuidString)"
        let bookmarkData: [String: Any] = [
            "chapterId": chapter.id.uuidString,
            "chapterNumber": chapter.chapterNumber,
            "page": currentPage,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        
        NotificationCenter.default.post(name: .titleUpdated, object: nil)
    }
    
    static func loadBookmarkFromUserDefaults(chapter: Chapter, titleID: UUID) -> Int? {
        let bookmarkKey = "currentBookmark_\(titleID.uuidString)"
                
        guard let bookmarkData = UserDefaults.standard.dictionary(forKey: bookmarkKey) else {
            return nil
        }
        
        guard let savedChapterId = bookmarkData["chapterId"] as? String else {
            return nil
        }
        
        guard let savedPage = bookmarkData["page"] as? Int else {
            return nil
        }
                
        if savedChapterId == chapter.id.uuidString {
            return savedPage
        } else {
            return nil
        }
    }
    
    // MARK: - Initial Page Setup
            
    static func setInitialPageIndex(
        displayImages: [UIImage],
        readingDirection: ReadingDirection,
        isDownloaded: Bool,
        hasRestoredFromBookmark: Bool,
        currentPageIndex: Binding<Int>,
        scrollToPage: @escaping (Int, Bool) -> Void,
        chapter: Chapter,
        titleID: UUID
    ) {
        guard !displayImages.isEmpty else {
            return
        }
        
        if let bookmarkedPage = loadBookmarkFromUserDefaults(chapter: chapter, titleID: titleID), !hasRestoredFromBookmark {
            let targetIndex: Int
            if readingDirection == .rightToLeft {
                targetIndex = displayImages.count - bookmarkedPage
            } else {
                targetIndex = bookmarkedPage - 1
            }
            
            let clampedIndex = max(0, min(displayImages.count - 1, targetIndex))
            currentPageIndex.wrappedValue = clampedIndex
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scrollToPage(currentPageIndex.wrappedValue, false)
            }
        } else {
            if readingDirection == .rightToLeft {
                currentPageIndex.wrappedValue = displayImages.count - 1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToPage(currentPageIndex.wrappedValue, false)
                }
            } else {
                currentPageIndex.wrappedValue = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToPage(currentPageIndex.wrappedValue, false)
                }
            }
        }
    }
    
    // MARK: - Modified Helper Methods

    static func handleImagesChange(
        oldValue: [UIImage],
        newValue: [UIImage],
        isDownloaded: Bool,
        originalImages: Binding<[UIImage]>,
        setInitialPageIndex: @escaping () -> Void,
        isChapterReady: Binding<Bool>,
        downloadProgress: Binding<String>,
        readerJava: ReaderViewJava,
        markChapterAsRead: @escaping () -> Void
    ) {
        if !isDownloaded {
            let imagesNowLoaded = !newValue.isEmpty

            if imagesNowLoaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    originalImages.wrappedValue = newValue
                    setInitialPageIndex()
                    isChapterReady.wrappedValue = true
                    
                    // MARK CHAPTER AS READ WHEN SUCCESSFULLY LOADED
                    markChapterAsRead()
                    
                    // Don't clear progress immediately - show success message briefly
                    downloadProgress.wrappedValue = "Chapter loaded successfully!"
                    
                    if readerJava.isLoading {
                        readerJava.isLoading = false
                    }
                    
                    // Clear success message after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        downloadProgress.wrappedValue = ""
                    }
                }
            }
        }
    }
    
    static func handleLoadedImagesChange(
        oldValue: [UIImage],
        newValue: [UIImage],
        isDownloaded: Bool,
        originalImages: Binding<[UIImage]>,
        setInitialPageIndex: @escaping () -> Void,
        isChapterReady: Binding<Bool>,
        markChapterAsRead: @escaping () -> Void
    ) {
        if isDownloaded && !newValue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                originalImages.wrappedValue = newValue
                setInitialPageIndex()
                isChapterReady.wrappedValue = true
                
                // MARK CHAPTER AS READ WHEN SUCCESSFULLY LOADED FROM STORAGE
                markChapterAsRead()
            }
        }
    }
}

// MARK: - Single Page View
struct SinglePageView: View {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var isZooming: Bool
    let isActive: Bool
    @Binding var zoomModeEnabled: Bool
    let onCenterTap: () -> Void
    let onExitZoomMode: (() -> Void)?
    
    var body: some View {
        ZoomableImageView(
            image: image,
            zoomScale: $zoomScale,
            lastZoomScale: $lastZoomScale,
            isZooming: $isZooming,
            isActive: isActive,
            zoomModeEnabled: $zoomModeEnabled,
            onCenterTap: onCenterTap,
            onExitZoomMode: onExitZoomMode
        )
        .drawingGroup()
        .allowsHitTesting(true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // FIX: Only ignore bottom safe area to respect top bar space
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
        }
        .onChange(of: isActive) { oldValue, newValue in
        }
    }
}


// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: UIImage
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    @Binding var isZooming: Bool
    let isActive: Bool
    @Binding var zoomModeEnabled: Bool
    let onCenterTap: () -> Void
    let onExitZoomMode: (() -> Void)?
    
    @State private var offset: CGSize = .zero
    @State private var initialOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(isActive ? zoomScale : 1.0)
                .offset(x: isActive ? offset.width : 0, y: isActive ? offset.height : 0)
                .frame(width: availableWidth, height: availableHeight)
                .background(Color.black)
                .clipped()
                .onTapGesture {
                    onCenterTap()
                }
                .gesture(
                    SimultaneousGesture(
                        magnificationGesture,
                        SimultaneousGesture(
                            dragGesture(geometry: geometry),
                            doubleTapGesture
                        )
                    )
                )
        }
        // FIX: Only ignore bottom safe area to respect top bar space
        .ignoresSafeArea(.all, edges: .bottom)
        .contentShape(Rectangle())
    }
    
    // Zoom Gesture
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Only allow zooming when in zoom mode or when navigation bars are hidden
                if isActive && zoomModeEnabled {
                    let delta = value / lastZoomScale
                    lastZoomScale = value
                    
                    let newScale = zoomScale * delta
                    let clampedScale = min(max(newScale, 1.0), 5.0)
                    
                    if clampedScale != zoomScale {
                        zoomScale = clampedScale
                        isZooming = clampedScale > 1.0
                    }
                    
                    // REMOVED: Automatic exit on pinch out
                    // User can now zoom out freely without exiting zoom mode
                }
            }
            .onEnded { value in
                guard isActive && zoomModeEnabled else { return }
                
                lastZoomScale = 1.0
                
                // Only exit zoom mode if user has zoomed out to less than full size
                if zoomScale <= 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        resetZoomAndPosition()
                    }
                    // Exit zoom mode after reset animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onExitZoomMode?()
                    }
                }
            }
    }
    
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isActive && zoomModeEnabled && isZooming else {
                    return
                }
                
                let maxOffsetX = max(0, (image.size.width * zoomScale - geometry.size.width) / 2)
                let maxOffsetY = max(0, (image.size.height * zoomScale - geometry.size.height) / 2)
                
                let newOffset = CGSize(
                    width: initialOffset.width + value.translation.width,
                    height: initialOffset.height + value.translation.height
                )
                
                offset = CGSize(
                    width: newOffset.width.clamped(to: -maxOffsetX...maxOffsetX),
                    height: newOffset.height.clamped(to: -maxOffsetY...maxOffsetY)
                )
            }
            .onEnded { value in
                guard isActive && zoomModeEnabled && isZooming else { return }
                initialOffset = offset
            }
    }
    
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                guard isActive && zoomModeEnabled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isZooming {
                        resetZoomAndPosition()
                    }
                    // Exit zoom mode after reset animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onExitZoomMode?()
                    }
                }
            }
    }
    
    private func resetZoomAndPosition() {
        zoomScale = 1.0
        offset = .zero
        initialOffset = .zero
        isZooming = false
        lastZoomScale = 1.0
    }
}


// Helper extension for clamping values
extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
    
enum TapLocation {
    case left, center, right
}

#Preview {
    ContentView()
}
