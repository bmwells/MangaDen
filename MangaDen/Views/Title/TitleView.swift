//
//  TitleView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI
import PhotosUI
import WebKit
import Network

struct TitleView: View {
    let title: Title
    @EnvironmentObject private var tabBarManager: TabBarManager
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedChapter: Chapter?
    @State private var showOptionsMenu = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    @State private var readingDirection: ReadingDirection = .rightToLeft
    @State private var showEditSheet = false
    @State private var editedTitle: String = ""
    @State private var editedAuthor: String = ""
    @State private var editedStatus: String = ""
    @State private var selectedCoverImage: UIImage?
    @State private var coverImageItem: PhotosPickerItem?
    @State private var showDownloadMode = false
    @State private var showManageMode = false
    @State private var manageMode: ManageMode = .uninstallDownloaded
    @State private var showDeleteChapterConfirmation = false
    @State private var chapterToDelete: Chapter?
    @State private var showUninstallAllConfirmation = false
    @State private var hiddenChapterURLs: Set<String> = []
    @State private var isRefreshing = false
    @State private var showRefreshResult = false
    @State private var refreshResultMessage = ""
    @State private var newChaptersCount = 0
    @State private var isOfflineMode = false
    @State private var bookmarkedChapters: Set<UUID> = []
    @State private var chapterSortOption: ChapterSortOption = .newToOld
    @StateObject private var autoRefreshManager = AutoRefreshManager.shared
    @State private var hasAutoRefreshed = false
    @Environment(\.dismiss) private var dismiss
    
    // Scrollbar state
    @State private var scrollProxy: ScrollViewProxy?
    @State private var scrollViewContentSize: CGFloat = 0
    @State private var visibleChapterRange: (min: Double, max: Double) = (0, 0)
    
    // Network monitor to detect offline mode
    private let networkMonitor = NWPathMonitor()
    @State private var networkStatus: NWPath.Status = .satisfied
    
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    // Filter chapters based on current tab, manage mode, and offline status
    var displayChapters: [Chapter] {
        let chapters: [Chapter]
        
        // If we're in offline mode, only show downloaded chapters
        if isOfflineMode {
            chapters = title.downloadedChapters.filter { !hiddenChapterURLs.contains($0.url) }
        } else if showManageMode && manageMode == .uninstallDownloaded {
            chapters = title.downloadedChapters
        } else {
            let allChapters = title.isDownloaded ? title.downloadedChapters : title.chapters
            chapters = allChapters.filter { !hiddenChapterURLs.contains($0.url) }
        }
        
        // Sort the chapters based on current sort option
        return sortChapters(chapters, by: chapterSortOption)
    }
    
    // Compute chapters with bookmark status
    var chaptersWithBookmarks: [Chapter] {
        displayChapters.map { chapter in
            var updatedChapter = chapter
            updatedChapter.isBookmarked = bookmarkedChapters.contains(chapter.id)
            return updatedChapter
        }
    }
    
    private var shouldShowChapterScrollbar: Bool {
        // Show scrollbar when we've scrolled past the cover image area
        return scrollOffset > 500 && !displayChapters.isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Offline mode indicator - only show when offline
                            if isOfflineMode {
                                OfflineModeBanner()
                            }
                            
                            TitleCoverImageSection(
                                title: title,
                                scrollOffset: scrollOffset,
                                selectedCoverImage: $selectedCoverImage,
                                geometry: geometry
                            )
                            
                            TitleInfoSection(
                                title: title,
                                editedTitle: editedTitle,
                                editedAuthor: editedAuthor,
                                editedStatus: editedStatus,
                                scrollOffset: scrollOffset
                            )
                            
                            if showDownloadMode {
                                DownloadModeControls(
                                    title: title,
                                    showDownloadMode: $showDownloadMode
                                )
                            }
                            
                            if showManageMode {
                                ManageModeControls(
                                    title: title,
                                    manageMode: $manageMode,
                                    showManageMode: $showManageMode,
                                    showUninstallAllConfirmation: $showUninstallAllConfirmation,
                                    onUninstallAll: uninstallAllChapters
                                )
                            }
                            
                            if !showDownloadMode && !showManageMode {
                                HStack {
                                    // Sort filter dropdown button
                                    Menu {
                                        Button(action: { sortChapters(by: .newToOld) }) {
                                            HStack {
                                                Text("Newest First")
                                                if chapterSortOption == .newToOld {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                        
                                        Button(action: { sortChapters(by: .oldToNew) }) {
                                            HStack {
                                                Text("Oldest First")
                                                if chapterSortOption == .oldToNew {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(size: 25))
                                                .bold()
                                        }
                                        .foregroundColor(currentAccentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 10)
                                        .background(ButtonBackground())
                                        .cornerRadius(8)
                                        .padding(.leading, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 5)

                                    }

                                    Spacer()
                                    
                                    ReadingDirectionSelector(
                                        readingDirection: $readingDirection,
                                        onDirectionChanged: saveReadingDirection
                                    )
                                    
                                    Spacer()
                                    
                                    // Bookmark button to scroll to bookmarked chapter
                                    if !bookmarkedChapters.isEmpty {
                                        Button(action: scrollToBookmarkedChapter) {
                                            HStack {
                                                Image(systemName: "bookmark.fill")
                                                    .font(.system(size: 25))
                                            }
                                            .foregroundColor(currentAccentColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 10)
                                            .background(ButtonBackground())
                                            .cornerRadius(8)
                                            .padding(.trailing, UIDevice.current.userInterfaceIdiom == .pad ? 30 : 5)
                                        }
                                    }
                                    
                                }
                                .padding(.horizontal)
                            }
                            
                            Divider()
                            
                            ChaptersListSection(
                                displayChapters: chaptersWithBookmarks,
                                readingDirection: readingDirection,
                                showDownloadMode: showDownloadMode,
                                showManageMode: showManageMode,
                                onDeleteChapter: { chapterToDelete = $0; showDeleteChapterConfirmation = true },
                                onMarkAsRead: markChapterAsRead,
                                titleID: title.id
                            )
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollContentSizeKey.self, value: geometry.size.height)
                                }
                            )
                        }
                        .background(GeometryReader {
                            Color.clear.preference(key: ViewOffsetKey.self,
                                value: -$0.frame(in: .named("scroll")).origin.y)
                        })
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ViewOffsetKey.self) { offset in
                        // Throttle scroll offset updates
                        DispatchQueue.main.async {
                            scrollOffset = offset
                        }
                    }
                    .onPreferenceChange(ScrollContentSizeKey.self) { newHeight in
                        // Throttle content size updates
                        DispatchQueue.main.async {
                            scrollViewContentSize = newHeight
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
                
                // Custom Scrollbar
                if shouldShowChapterScrollbar {
                    ChapterScrollbar(
                        chapters: displayChapters,
                        visibleRange: visibleChapterRange,
                        onScrollToChapter: scrollToChapter
                    )
                    .frame(width: 60)
                    .padding(.trailing, 8)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(currentAccentColor)
                        .padding(8)
                }
            }
            
            ToolbarItem(placement: .principal) {
                Text("")
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                OptionsMenu(
                    isRefreshing: isRefreshing,
                    title: title,
                    onRefresh: refreshTitle,
                    onEdit: { showEditSheet = true },
                    onDownloadModeToggle: {
                        withAnimation {
                            showDownloadMode.toggle()
                            if showDownloadMode { showManageMode = false }
                        }
                    },
                    onManageModeToggle: {
                        withAnimation {
                            showManageMode.toggle()
                            if showManageMode { showDownloadMode = false }
                        }
                    },
                    onToggleArchive: toggleArchiveStatus,
                    onDelete: { showDeleteConfirmation = true }
                )
                .font(.title2)
                .foregroundColor(currentAccentColor)
                .padding(8)
                .disabled(isOfflineMode && isRefreshing) // Only disable refresh when offline
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alerts(
            showDeleteConfirmation: $showDeleteConfirmation,
            showDeleteChapterConfirmation: $showDeleteChapterConfirmation,
            showUninstallAllConfirmation: $showUninstallAllConfirmation,
            showRefreshResult: $showRefreshResult,
            manageMode: manageMode,
            chapterToDelete: chapterToDelete,
            title: title,
            refreshResultMessage: refreshResultMessage,
            onDeleteTitle: deleteTitle,
            onDeleteChapter: { deleteChapter($0) },
            onUninstallAll: uninstallAllChapters
        )
        .sheet(isPresented: $showEditSheet) {
            EditTitleView(
                title: title,
                editedTitle: $editedTitle,
                editedAuthor: $editedAuthor,
                editedStatus: $editedStatus,
                selectedCoverImage: $selectedCoverImage,
                coverImageItem: $coverImageItem,
                onSave: saveTitleChanges
            )
        }
        .refreshOverlay(isRefreshing: isRefreshing)
        .onAppear(perform: onAppearActions)
        .onDisappear {
            // Stop network monitoring when view disappears
            networkMonitor.cancel()
        }
        // Listen for bookmark updates
        .onReceive(NotificationCenter.default.publisher(for: .titleUpdated)) { _ in
            loadCurrentBookmark()
        }
    }
    
    // MARK: - Bookmark Management
        
    // Load current bookmark from UserDefaults
    private func loadCurrentBookmark() {
        let bookmarkKey = "currentBookmark_\(title.id.uuidString)"
        
        guard let bookmarkData = UserDefaults.standard.dictionary(forKey: bookmarkKey),
              let chapterIdString = bookmarkData["chapterId"] as? String,
              let chapterId = UUID(uuidString: chapterIdString)
            else {
            // No bookmark found, clear all
            bookmarkedChapters.removeAll()
            return
        }
        
        // Set only this chapter as bookmarked
        bookmarkedChapters = [chapterId]
    }
    
    // MARK: - Bookmark Scrolling
    private func scrollToBookmarkedChapter() {
        guard let bookmarkedChapterId = bookmarkedChapters.first,
              let bookmarkedChapter = displayChapters.first(where: { $0.id == bookmarkedChapterId }) else {
            return
        }
        
        scrollToChapter(bookmarkedChapter)
    }
    
    // MARK: - Chapter Sorting
    private func sortChapters(_ chapters: [Chapter], by option: ChapterSortOption) -> [Chapter] {
        switch option {
        case .newToOld:
            return chapters.sorted { $0.chapterNumber > $1.chapterNumber }
        case .oldToNew:
            return chapters.sorted { $0.chapterNumber < $1.chapterNumber }
        }
    }

    private func sortChapters(by option: ChapterSortOption) {
        chapterSortOption = option
        saveSortOption()
    }

    private func loadSortOption() {
        let sortKey = "chapterSortOption_\(title.id.uuidString)"
        if let savedSort = UserDefaults.standard.string(forKey: sortKey),
           let option = ChapterSortOption(rawValue: savedSort) {
            chapterSortOption = option
        } else {
            chapterSortOption = .newToOld // Default
        }
    }

    private func saveSortOption() {
        let sortKey = "chapterSortOption_\(title.id.uuidString)"
        UserDefaults.standard.set(chapterSortOption.rawValue, forKey: sortKey)
    }
    
    // MARK: - Scrollbar Methods
    
    private func scrollToChapter(_ chapter: Chapter) {
        withAnimation {
            scrollProxy?.scrollTo(chapter.id, anchor: .top)
        }
    }
    
    // MARK: - Lifecycle
    private func onAppearActions() {
           loadReadingDirection()
           loadHiddenChapters()
           loadCurrentBookmark()
           loadSortOption()
           editedTitle = title.title
           editedAuthor = title.author
           editedStatus = title.status
           manageMode = !title.downloadedChapters.isEmpty ? .uninstallDownloaded : .hideFromList
           tabBarManager.isTabBarHidden = true
           
           // Start network monitoring
           startNetworkMonitoring()
           
           // NEW: Check for automatic refresh
           checkForAutoRefresh()
       }
    
    // MARK: - Network Monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.networkStatus = path.status
                self.isOfflineMode = path.status != .satisfied
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    
    // NEW: Automatic refresh check
        private func checkForAutoRefresh() {
            // Only auto-refresh if we haven't already done so in this session
            // and if we're not in offline mode
            guard !hasAutoRefreshed && !isOfflineMode else { return }
            
            if autoRefreshManager.shouldRefreshTitle(title) {
                // Small delay to let the view fully appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    refreshTitle()
                    hasAutoRefreshed = true
                    autoRefreshManager.markTitleRefreshed(title)
                }
            }
        }
        
    // MARK: - Refresh Title Function
    private func refreshTitle() {
        // Don't allow refresh in offline mode
        guard !isOfflineMode else {
            refreshResultMessage = "Cannot refresh while offline"
            showRefreshResult = true
            return
        }
        
        isRefreshing = true
        
        // Mark refresh attempt immediately when starting
        autoRefreshManager.markRefreshAttempt(title)
        
        let webView = WKWebView()
        WebViewUserAgentManager.setDesktopUserAgent(for: webView)
        
        if let sourceURL = title.sourceURL, let url = URL(string: sourceURL) {
            webView.load(URLRequest(url: url))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                TitleRefreshManager.refreshTitle(in: webView, for: title) { result in
                    DispatchQueue.main.async {
                        isRefreshing = false
                        
                        switch result {
                        case .success(let newChapters):
                            newChaptersCount = newChapters.count
                            refreshResultMessage = newChaptersCount > 0 ?
                                "Title Refresh Successful. \(newChaptersCount) new Chapter\(newChaptersCount == 1 ? "" : "s") found." :
                                "No new Chapters found."
                            
                            // Note: Refresh timestamp was already updated when the attempt started
                            
                        case .failure(let error):
                            refreshResultMessage = "\(error)"
                            // Refresh timestamp was already updated when the attempt started
                            // This prevents immediate retries on failure
                        }
                        
                        showRefreshResult = true
                        NotificationCenter.default.post(name: .titleUpdated, object: nil)
                    }
                }
            }
        } else {
            isRefreshing = false
            refreshResultMessage = "Invalid source URL for refresh"
            showRefreshResult = true
            // NEW: Even for immediate failures, mark the attempt
            autoRefreshManager.markRefreshAttempt(title)
        }
    }
    
    
    // MARK: - Manage Mode Functions
    private func deleteChapter(_ chapter: Chapter) {
        switch manageMode {
        case .hideFromList:
            hiddenChapterURLs.insert(chapter.url)
            saveHiddenChapters()
        case .uninstallDownloaded:
            uninstallChapter(chapter)
        }
        NotificationCenter.default.post(name: .titleUpdated, object: nil)
    }
    
    private func uninstallChapter(_ chapter: Chapter) {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            // Remove downloaded chapter files
            let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapter.id.uuidString)")
            if fileManager.fileExists(atPath: chapterDirectory.path) {
                try fileManager.removeItem(at: chapterDirectory)
            }
            
            // Update chapter download status
            var updatedTitle = title
            if let chapterIndex = updatedTitle.chapters.firstIndex(where: { $0.id == chapter.id }) {
                updatedTitle.chapters[chapterIndex].isDownloaded = false
                saveUpdatedTitle(updatedTitle)
            }
            
        } catch {
            print("Error uninstalling chapter: \(error)")
        }
    }
    
    private func uninstallAllChapters() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            // Remove all downloaded chapters for this title
            for chapter in title.downloadedChapters {
                let chapterDirectory = documentsDirectory.appendingPathComponent("Downloads/\(chapter.id.uuidString)")
                if fileManager.fileExists(atPath: chapterDirectory.path) {
                    try fileManager.removeItem(at: chapterDirectory)
                }
            }
            
            // Update all chapters to not downloaded
            var updatedTitle = title
            for index in updatedTitle.chapters.indices {
                updatedTitle.chapters[index].isDownloaded = false
            }
            
            // Save the updated title
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            let titleData = try JSONEncoder().encode(updatedTitle)
            try titleData.write(to: titleFile)
                        
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
        } catch {
            print("Error uninstalling all chapters: \(error)")
        }
    }
    
    private func saveUpdatedTitle(_ updatedTitle: Title) {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not access documents directory")
                return
            }
            
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            let titleData = try JSONEncoder().encode(updatedTitle)
            try titleData.write(to: titleFile)
                        
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
        } catch {
            print("Error saving updated title: \(error)")
        }
    }
    
    // MARK: - Hidden Chapters Management
    private func loadHiddenChapters() {
        let hiddenKey = "hiddenChapters_\(title.id.uuidString)"
        if let savedHidden = UserDefaults.standard.array(forKey: hiddenKey) as? [String] {
            hiddenChapterURLs = Set(savedHidden)
        }
    }
    
    private func saveHiddenChapters() {
        let hiddenKey = "hiddenChapters_\(title.id.uuidString)"
        UserDefaults.standard.set(Array(hiddenChapterURLs), forKey: hiddenKey)
    }
    
    private func loadReadingDirection() {
        let directionKey = "readingDirection_\(title.id.uuidString)"
        
        if let savedDirection = UserDefaults.standard.string(forKey: directionKey),
           let direction = ReadingDirection(rawValue: savedDirection) {
            readingDirection = direction
        } else if let globalDefault = UserDefaults.standard.string(forKey: "defaultReadingDirection"),
                  let direction = ReadingDirection(rawValue: globalDefault) {
            readingDirection = direction
        } else {
            readingDirection = .rightToLeft
        }
    }
    
    private func saveReadingDirection() {
        let directionKey = "readingDirection_\(title.id.uuidString)"
        UserDefaults.standard.set(readingDirection.rawValue, forKey: directionKey)
    }
    
    private func markChapterAsRead(chapter: Chapter) {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            // Update the chapter's read status
            var updatedTitle = title
            if let chapterIndex = updatedTitle.chapters.firstIndex(where: { $0.id == chapter.id }) {
                updatedTitle.chapters[chapterIndex].isRead = true
                
                // Save the updated title
                let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
                let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
                
                let titleData = try JSONEncoder().encode(updatedTitle)
                try titleData.write(to: titleFile)
                
                NotificationCenter.default.post(name: .chapterReadStatusChanged, object: nil)
                NotificationCenter.default.post(name: .titleUpdated, object: nil)
            }
        } catch {
            print("Error marking chapter as read: \(error)")
        }
    }
    
    private func toggleArchiveStatus() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not access documents directory")
                return
            }
            
            // Update the title's archive status
            var updatedTitle = title
            updatedTitle.isArchived.toggle()
            
            // Save the updated title
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            let titleData = try JSONEncoder().encode(updatedTitle)
            try titleData.write(to: titleFile)
            
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
            tabBarManager.isTabBarHidden = false
            dismiss()
            
        } catch {
            print("Error updating archive status: \(error)")
        }
    }

    private func deleteTitle() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not access documents directory")
                return
            }
            
            // First, uninstall all downloaded chapters for this title
            uninstallAllChapters()
            
            // Delete the title file
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            if fileManager.fileExists(atPath: titleFile.path) {
                try fileManager.removeItem(at: titleFile)
            }
            
            NotificationCenter.default.post(name: .titleDeleted, object: nil)
            
            tabBarManager.isTabBarHidden = false
            dismiss()
            
        } catch {
            print("Error deleting title: \(error)")
        }
    }
    
    
    private func saveTitleChanges() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not access documents directory")
                return
            }
            
            // Update the title with new data
            var updatedTitle = title
            updatedTitle.title = editedTitle
            updatedTitle.author = editedAuthor
            updatedTitle.status = editedStatus
            
            // Update cover image if changed
            if let newCoverImage = selectedCoverImage {
                updatedTitle.coverImageData = newCoverImage.jpegData(compressionQuality: 0.8)
            }
            
            // Save the updated title
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            let titleData = try JSONEncoder().encode(updatedTitle)
            try titleData.write(to: titleFile)
            
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
        } catch {
            print("Error saving title changes: \(error)")
        }
    }
    
    private func archiveButtonText() -> String {
        return title.isArchived ? "Move to Reading" : "Archive Title"
    }

    private func archiveButtonIcon() -> String {
        return title.isArchived ? "book" : "archivebox"
    }
}

// MARK: - Supporting Enums
enum ChapterSortOption: String, CaseIterable {
    case newToOld = "newToOld"
    case oldToNew = "oldToNew"
}

// MARK: - Button Background (Sort & Bookmark)
struct ButtonBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    var body: some View {
        Group {
            if colorScheme == .dark {
                Color.gray.opacity(0.3) // Gray background for dark mode
            } else {
                currentAccentColor.opacity(0.2) // Blue background for light mode
            }
        }
    }
}

// MARK: - Chapter Scrollbar Component
struct ChapterScrollbar: View {
    let chapters: [Chapter]
    let visibleRange: (min: Double, max: Double)
    let onScrollToChapter: (Chapter) -> Void
    
    private var topChapter: Chapter? {
        // Highest chapter number
        chapters.first
    }
    private var middleChapter: Chapter? {
        // Middle chapter of the entire title
        guard !chapters.isEmpty else { return nil }
        let middleIndex = chapters.count / 2
        return chapters[middleIndex]
    }
    private var bottomChapter: Chapter? {
        // Lowest chapter number
        chapters.last
    }
    
    // Calculate scroll position based on visible range
    private var scrollPercentage: Double {
        guard chapters.count > 1 else { return 0 }
        return visibleRange.min / Double(chapters.count - 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Single tap gesture for the entire scrollbar
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleScrollbarTap(location: location, geometry: geometry)
                    }
                
                // Position numbers that move with scroll
                VStack(spacing: 0) {
                    // Top chapter number
                    if let topChapter = topChapter {
                        ChapterScrollbarNumber(
                            chapter: topChapter,
                            position: .top,
                            onTap: { onScrollToChapter(topChapter) }
                        )
                    }
                    
                    Spacer()
                    
                    // Middle chapter number
                    if let middleChapter = middleChapter {
                        ChapterScrollbarNumber(
                            chapter: middleChapter,
                            position: .middle,
                            onTap: { onScrollToChapter(middleChapter) }
                        )
                    }
                    
                    Spacer()
                    
                    // Bottom chapter number
                    if let bottomChapter = bottomChapter {
                        ChapterScrollbarNumber(
                            chapter: bottomChapter,
                            position: .bottom,
                            onTap: { onScrollToChapter(bottomChapter) }
                        )
                    }
                }
                .offset(y: -geometry.size.height * scrollPercentage)
            }
        }
        .frame(width: 42,  height: 200)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black.opacity(0.03))
        )
        .clipped()
    }
    
    private func handleScrollbarTap(location: CGPoint, geometry: GeometryProxy) {
        let tapY = location.y
        let scrollbarHeight = geometry.size.height
        
        // Calculate which chapter was tapped based on position
        let tapPercentage = Double(tapY / scrollbarHeight)
        let chapterIndex = Int(Double(chapters.count) * tapPercentage)
        
        // Clamp the index to valid range
        let clampedIndex = max(0, min(chapters.count - 1, chapterIndex))
        
        if clampedIndex < chapters.count {
            onScrollToChapter(chapters[clampedIndex])
        }
    }
}

struct ChapterScrollbarNumber: View {
    let chapter: Chapter
    let position: ScrollbarPosition
    let onTap: () -> Void
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(chapter.formattedChapterNumber)
                .font(.headline)
                .foregroundColor(currentAccentColor)
                .frame(width: 40, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fontSize: CGFloat {
        switch position {
        case .top, .bottom:
            return 14
        case .middle:
            return 16
        }
    }
}


// MARK: - Offline Mode Banner
struct OfflineModeBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .font(.title)
                .foregroundColor(.orange)
            Text("Offline Mode")
                .font(.title3)
                .foregroundColor(.orange)
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct ScrollContentSizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Supporting Types
enum ReadingDirection: String, CaseIterable {
    case leftToRight = "leftToRight"
    case rightToLeft = "rightToLeft"
}

enum ScrollbarPosition {
    case top, middle, bottom
}

enum ManageMode {
    case uninstallDownloaded
    case hideFromList
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

#Preview {
    ContentView()
}
