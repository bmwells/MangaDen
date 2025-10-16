//
//  ReaderView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

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
    @State private var zoomModeEnabled: Bool = false
    
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
            let pageNumber = totalPages - currentPageIndex
            print("RTL Page Calc: currentPageIndex=\(currentPageIndex), totalPages=\(totalPages), result=\(pageNumber)")
            return pageNumber
        } else {
            return currentPageIndex + 1
        }
    }
    
    // Computed property for scrollbar progress
    private var scrollbarProgress: CGFloat {
        guard displayImages.count > 1 else { return 0 }
        
        if readingDirection == .rightToLeft {
            return 1.0 - (CGFloat(currentPageIndex) / CGFloat(displayImages.count - 1))
        } else {
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
            if showNavigationBars && !displayImages.isEmpty && !isZooming && !zoomModeEnabled {
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
        .navigationBarBackButtonHidden(true)
        .toolbar(content: toolbarContent)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(!showNavigationBars)
        .onAppear {
            onAppearAction()
        }
        .onDisappear {
            onDisappearAction()
        }
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
    
    // MARK: - Reader Content View
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
                                    isActive: index == currentPageIndex,
                                    zoomModeEnabled: $zoomModeEnabled,
                                    onCenterTap: {
                                        print("🎯 Center tap received in ReaderView")
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showNavigationBars.toggle()
                                            print("📊 Navigation bars now: \(showNavigationBars)")
                                        }
                                    },
                                    onExitZoomMode: {
                                        print("🚪 Exit zoom mode requested from SinglePageView")
                                        toggleZoomMode()
                                    }
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .onAppear {
                        scrollProxy = proxy
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToPage(currentPageIndex, animated: false)
                        }
                    }
                    .onChange(of: currentPageIndex) { oldValue, newValue in
                        if oldValue != newValue {
                            scrollToPage(newValue, animated: true)
                        }
                    }
                }
            }
            
            // Navigation overlay - only show when not in zoom mode
            if !zoomModeEnabled {
                navigationOverlay
            }
        }
    }

    private var navigationOverlay: some View {
        ZStack {
            // Always have tap areas present for gestures
            HStack(spacing: 0) {
                // Left tap area (previous page) - 20% of screen width
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("⬅️ Left tap area - navigating previous")
                        navigateToPreviousPage()
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.2) // 20% width
                
                // Center tap area (toggle bars) - 60% of screen width
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🎯 Center tap area - toggling bars")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNavigationBars.toggle()
                            print("📊 Navigation bars now: \(showNavigationBars)")
                        }
                    }
                    .frame(maxWidth: .infinity) // Takes remaining space (60%)
                
                // Right tap area (next page) - 20% of screen width
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("➡️ Right tap area - navigating next")
                        navigateToNextPage()
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.2) // 20% width
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    print("👆 Drag gesture ended")
                    handleSwipeGesture(value: value)
                }
        )
        .allowsHitTesting(true)
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
        
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if showNavigationBars {
                zoomButton
                downloadButton
            }
        }
    }
    
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
    
    
    
    private var zoomButton: some View {
        Button(action: {
            toggleZoomMode()
        }) {
            Image(systemName: "plus.magnifyingglass")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
        }
    }
        
    private var downloadButton: some View {
        Button(action: {
            downloadCurrentImage()
        }) {
            Image(systemName: "square.and.arrow.down")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .padding(.trailing, 10)
        }
    }
    
    // MARK: - Actions
    
    private func toggleZoomMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if zoomModeEnabled {
                // Exiting zoom mode - reset zoom and position with proper animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    isZooming = false
                }
                // Ensure we wait for the zoom reset animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    zoomModeEnabled = false
                    showNavigationBars = true
                    print("🔍 Exited zoom mode - reset zoom to 1.0")
                }
            } else {
                // Entering zoom mode
                zoomModeEnabled = true
                showNavigationBars = false
                print("🔍 Entered zoom mode")
            }
        }
    }
    
    private func onAppearAction() {
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
        updateBookmark()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tabBarManager.isTabBarHidden = true
        }
    }
    
    private func loadChapter() {
        ReaderCoordinator.loadChapter(
            chapter: chapter,
            readerJava: readerJava,
            isChapterReady: $isChapterReady
        )
    }
    
    private func loadFromStorage() {
        ReaderCoordinator.loadFromStorage(
            chapter: chapter,
            isLoadingFromStorage: $isLoadingFromStorage,
            originalImages: $originalImages,
            loadedImages: $loadedImages,
            isChapterReady: $isChapterReady
        ) {
            setInitialPageIndex()
        }
    }
    
    private func markChapterAsRead() {
        ReaderCoordinator.markChapterAsRead(chapter: chapter)
    }
    
    private func downloadCurrentImage() {
        ReaderCoordinator.downloadCurrentImage(
            displayImages: displayImages,
            currentPageIndex: currentPageIndex,
            downloadAlertMessage: $downloadAlertMessage,
            showDownloadAlert: $showDownloadAlert
        )
    }
    
    private func handleTapGesture(location: TapLocation) {
        ReaderCoordinator.handleTapGesture(
            location: location,
            showNavigationBars: $showNavigationBars,
            isZooming: isZooming,
            resetZoom: resetZoom,
            navigateToPreviousPage: navigateToPreviousPage,
            navigateToNextPage: navigateToNextPage
        )
    }
    
    private func handleSwipeGesture(value: DragGesture.Value) {
        ReaderCoordinator.handleSwipeGesture(
            value: value,
            isZooming: isZooming,
            navigateToPreviousPage: navigateToPreviousPage,
            navigateToNextPage: navigateToNextPage
        )
    }
    
    private func navigateToNextPage() {
        ReaderCoordinator.navigateToNextPage(
            currentPageIndex: $currentPageIndex,
            displayImages: displayImages,
            scrollToPage: scrollToPage,
            resetZoom: resetZoom
        )
    }
    
    private func navigateToPreviousPage() {
        ReaderCoordinator.navigateToPreviousPage(
            currentPageIndex: $currentPageIndex,
            displayImages: displayImages,
            scrollToPage: scrollToPage,
            resetZoom: resetZoom
        )
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            zoomScale = 1.0
            lastZoomScale = 1.0
            isZooming = false
        }
    }
    
    private func updateDownloadProgress(progress: String) {
        ReaderCoordinator.updateDownloadProgress(
            progress: progress,
            downloadProgress: $downloadProgress
        )
    }
    
    private func scrollToPage(_ pageIndex: Int, animated: Bool) {
        ReaderCoordinator.scrollToPage(
            pageIndex,
            animated: animated,
            scrollProxy: scrollProxy
        )
    }
    
    private func handlePageChange(oldValue: Int, newValue: Int) {
        ReaderCoordinator.handlePageChange(
            oldValue: oldValue,
            newValue: newValue,
            scrollToPage: scrollToPage,
            updateBookmark: updateBookmark
        )
    }
    
    private func updateBookmark() {
        ReaderCoordinator.updateBookmark(
            displayImages: displayImages,
            currentPageIndex: currentPageIndex,
            readingDirection: readingDirection,
            chapter: chapter,
            titleID: titleID
        )
    }
    
    private func setInitialPageIndex() {
        ReaderCoordinator.setInitialPageIndex(
            displayImages: displayImages,
            readingDirection: readingDirection,
            isDownloaded: isDownloaded,
            hasRestoredFromBookmark: hasRestoredFromBookmark,
            currentPageIndex: $currentPageIndex,
            scrollToPage: scrollToPage,
            chapter: chapter,
            titleID: titleID
        )
    }
    
    private func handleImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        ReaderCoordinator.handleImagesChange(
            oldValue: oldValue,
            newValue: newValue,
            isDownloaded: isDownloaded,
            originalImages: $originalImages,
            setInitialPageIndex: setInitialPageIndex,
            isChapterReady: $isChapterReady,
            downloadProgress: $downloadProgress,
            readerJava: readerJava
        )
    }
    
    private func handleLoadedImagesChange(oldValue: [UIImage], newValue: [UIImage]) {
        ReaderCoordinator.handleLoadedImagesChange(
            oldValue: oldValue,
            newValue: newValue,
            isDownloaded: isDownloaded,
            originalImages: $originalImages,
            setInitialPageIndex: setInitialPageIndex,
            isChapterReady: $isChapterReady
        )
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
                if !isDragging {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onCenterTap()
                        }
                        .zIndex(0)
                }
                
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 300, height: 12)
                    .zIndex(1)
                
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
                
                Capsule()
                    .fill(Color.clear)
                    .frame(width: 300, height: 12)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let tapLocation = location.x
                        let tapProgress = calculateProgressFromPosition(position: tapLocation, width: 300)
                        onTap(tapProgress)
                    }
                    .zIndex(3)
                
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
                    .zIndex(4)
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
            circlePosition = width - (progress * width)
        } else {
            circlePosition = progress * width
        }
        
        return max(15, min(width - 15, circlePosition))
    }
    
    private func calculateProgressWidth(width: CGFloat) -> CGFloat {
        return progress * width
    }
    
    private func calculateProgressPosition(width: CGFloat) -> CGFloat {
        if readingDirection == .rightToLeft {
            return width - (progress * width / 2)
        } else {
            return (progress * width) / 2
        }
    }
    
    private func calculateProgressFromPosition(position: CGFloat, width: CGFloat) -> CGFloat {
        let clampedPosition = max(15, min(width - 15, position))
        let progress: CGFloat
        
        if readingDirection == .rightToLeft {
            progress = clampedPosition / width
        } else {
            progress = clampedPosition / width
        }
        
        return max(0, min(1, progress))
    }
}

#Preview {
    ContentView()
}
