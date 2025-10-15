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
        // Note: hasRestoredFromBookmark would need to be managed by the parent view
        
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
        clearCache: @escaping () -> Void,
        updateBookmark: @escaping () -> Void,
        tabBarManager: TabBarManager
    ) {
        if !isDownloaded {
            clearCache()
        }
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
                
                print("Loading \(imageFiles.count) images from storage with order:")
                for (index, file) in imageFiles.enumerated() {
                    print("  Page \(index): \(file.lastPathComponent)")
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
                let imagesCount = finalImages.count
                
                DispatchQueue.main.async {
                    originalImages.wrappedValue = finalImages
                    loadedImages.wrappedValue = finalImages
                    isLoadingFromStorage.wrappedValue = false
                    
                    print("Loaded \(imagesCount) images from storage for downloaded chapter")
                    
                    isChapterReady.wrappedValue = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        setInitialPageIndex()
                        print("Initial page set for downloaded chapter")
                    }
                }
            } catch {
                print("Error loading chapter from storage: \(error)")
                DispatchQueue.main.async {
                    isLoadingFromStorage.wrappedValue = false
                    isChapterReady.wrappedValue = true
                }
            }
        }
    }
    
    static func markChapterAsRead(chapter: Chapter) {
        NotificationCenter.default.post(
            name: .chapterReadStatusChanged,
            object: nil,
            userInfo: ["chapterId": chapter.id]
        )
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
        navigateToPreviousPage: @escaping () -> Void,
        navigateToNextPage: @escaping () -> Void
    ) {
        switch location {
        case .left:
            navigateToPreviousPage()
        case .center:
            withAnimation(.easeInOut(duration: 0.2)) {
                showNavigationBars.wrappedValue.toggle()
            }
        case .right:
            navigateToNextPage()
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
        resetZoom: @escaping () -> Void
    ) {
        guard currentPageIndex.wrappedValue < displayImages.count - 1 else { return }
        let newIndex = currentPageIndex.wrappedValue + 1
        print("Next page: \(currentPageIndex.wrappedValue) -> \(newIndex)")
        currentPageIndex.wrappedValue = newIndex
        scrollToPage(currentPageIndex.wrappedValue, true)
        resetZoom()
    }
    
    static func navigateToPreviousPage(
        currentPageIndex: Binding<Int>,
        displayImages: [UIImage],
        scrollToPage: @escaping (Int, Bool) -> Void,
        resetZoom: @escaping () -> Void
    ) {
        guard currentPageIndex.wrappedValue > 0 else { return }
        let newIndex = currentPageIndex.wrappedValue - 1
        print("Previous page: \(currentPageIndex.wrappedValue) -> \(newIndex)")
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
        print("Scrolling to page index: \(pageIndex)")
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
        
        print("Bookmark updated: Chapter \(chapter.formattedChapterNumber), Page \(currentPage)")
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
        print("Bookmark saved to UserDefaults: Title \(titleID.uuidString), Chapter \(chapter.formattedChapterNumber), Page \(currentPage)")
        
        NotificationCenter.default.post(name: .titleUpdated, object: nil)
    }
    
    static func loadBookmarkFromUserDefaults(chapter: Chapter, titleID: UUID) -> Int? {
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
        
        if savedChapterId == chapter.id.uuidString {
            print("Bookmark found for current chapter: Chapter \(chapter.formattedChapterNumber), Page \(savedPage)")
            return savedPage
        } else {
            print("Bookmark exists but for different chapter: \(savedChapterId) vs current: \(chapter.id.uuidString)")
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
            print("No display images available for setting initial page")
            return
        }
        
        print("Setting initial page index for \(displayImages.count) images")
        print("Reading direction: \(readingDirection)")
        print("Chapter is downloaded: \(isDownloaded)")
        print("hasRestoredFromBookmark: \(hasRestoredFromBookmark)")
        
        if let bookmarkedPage = loadBookmarkFromUserDefaults(chapter: chapter, titleID: titleID), !hasRestoredFromBookmark {
            print("Attempting to restore from bookmark: page \(bookmarkedPage)")
            
            let targetIndex: Int
            if readingDirection == .rightToLeft {
                targetIndex = displayImages.count - bookmarkedPage
                print("RTL conversion: bookmarkedPage \(bookmarkedPage) -> targetIndex \(targetIndex)")
            } else {
                targetIndex = bookmarkedPage - 1
                print("LTR conversion: bookmarkedPage \(bookmarkedPage) -> targetIndex \(targetIndex)")
            }
            
            let clampedIndex = max(0, min(displayImages.count - 1, targetIndex))
            currentPageIndex.wrappedValue = clampedIndex
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scrollToPage(currentPageIndex.wrappedValue, false)
                print("Scrolled to bookmarked page: \(currentPageIndex.wrappedValue)")
            }
        } else {
            if readingDirection == .rightToLeft {
                currentPageIndex.wrappedValue = displayImages.count - 1
                print("RTL INIT: Set currentPageIndex to \(currentPageIndex.wrappedValue) for Page 1")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToPage(currentPageIndex.wrappedValue, false)
                }
            } else {
                currentPageIndex.wrappedValue = 0
                print("LTR: Set initial page to 0 for \(displayImages.count) display images")
                
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
        readerJava: ReaderViewJava
    ) {
        if !isDownloaded {
            let imagesNowLoaded = !newValue.isEmpty
            
            if imagesNowLoaded {
                print("Images loaded: \(newValue.count), setting chapter ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    originalImages.wrappedValue = newValue
                    setInitialPageIndex()
                    isChapterReady.wrappedValue = true
                    downloadProgress.wrappedValue = ""
                    
                    if readerJava.isLoading {
                        print("Forcing readerJava isLoading to false")
                        readerJava.isLoading = false
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
        isChapterReady: Binding<Bool>
    ) {
        if isDownloaded && !newValue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                originalImages.wrappedValue = newValue
                setInitialPageIndex()
                isChapterReady.wrappedValue = true
            }
        }
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
        .drawingGroup()
        .allowsHitTesting(isActive)
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
