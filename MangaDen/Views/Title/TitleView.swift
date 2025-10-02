import SwiftUI
import PhotosUI
import WebKit

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
    @Environment(\.dismiss) private var dismiss
    
    // Filter chapters based on current tab and manage mode
    var displayChapters: [Chapter] {
        if showManageMode && manageMode == .uninstallDownloaded {
            return title.downloadedChapters
        } else {
            let chapters = title.isDownloaded ? title.downloadedChapters : title.chapters
            return chapters.filter { !hiddenChapterURLs.contains($0.url) }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
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
                            showUninstallAllConfirmation: $showUninstallAllConfirmation
                        )
                    }
                    
                    if !showDownloadMode && !showManageMode {
                        ReadingDirectionSelector(
                            readingDirection: $readingDirection,
                            onDirectionChanged: saveReadingDirection
                        )
                    }
                    
                    Divider()
                    
                    ChaptersListSection(
                        displayChapters: displayChapters,
                        readingDirection: readingDirection,
                        showDownloadMode: showDownloadMode,
                        showManageMode: showManageMode,
                        onDeleteChapter: { chapterToDelete = $0; showDeleteChapterConfirmation = true },
                        onMarkAsRead: markChapterAsRead
                    )
                }
                .padding(.vertical)
                .background(GeometryReader {
                    Color.clear.preference(key: ViewOffsetKey.self,
                        value: -$0.frame(in: .named("scroll")).origin.y)
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ViewOffsetKey.self) { offset in
                scrollOffset = offset
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
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
                .padding(8)
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
            onDeleteChapter: { deleteChapter($0) }
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
    }
    
    // MARK: - Lifecycle
    private func onAppearActions() {
        loadReadingDirection()
        loadHiddenChapters()
        editedTitle = title.title
        editedAuthor = title.author
        editedStatus = title.status
        manageMode = !title.downloadedChapters.isEmpty ? .uninstallDownloaded : .hideFromList
        tabBarManager.isTabBarHidden = true
        print("TitleView appeared - Tab bar hidden: \(tabBarManager.isTabBarHidden)")
    }
    
    // MARK: - Refresh Title Function
    private func refreshTitle() {
        isRefreshing = true
        
        let webView = WKWebView()
        AddTitleJAVA.setDesktopUserAgent(for: webView)
        
        if let sourceURL = title.sourceURL, let url = URL(string: sourceURL) {
            webView.load(URLRequest(url: url))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                AddTitleJAVA.refreshTitle(in: webView, for: title) { result in
                    DispatchQueue.main.async {
                        isRefreshing = false
                        
                        switch result {
                        case .success(let newChapters):
                            newChaptersCount = newChapters.count
                            refreshResultMessage = newChaptersCount > 0 ?
                                "Title Refresh Successful. \(newChaptersCount) new Chapter\(newChaptersCount == 1 ? "" : "s") found." :
                                "No new Chapters found."
                        case .failure(let error):
                            refreshResultMessage = "Refresh failed: \(error)"
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
                print("Uninstalled chapter: \(chapter.title ?? "Chapter \(chapter.formattedChapterNumber)")")
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
                    print("Removed chapter directory: \(chapterDirectory.lastPathComponent)")
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
            
            print("Uninstalled all chapters for: \(title.title)")
            
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
            
            print("Successfully saved updated title: \(updatedTitle.title)")
            
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
            print("Updated archive status for: \(title.title) - isArchived: \(updatedTitle.isArchived)")
            
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
            
            // Delete the title file
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            if fileManager.fileExists(atPath: titleFile.path) {
                try fileManager.removeItem(at: titleFile)
                print("Deleted title file: \(titleFile.lastPathComponent)")
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
            print("Updated title info: \(updatedTitle.title) by \(updatedTitle.author) with status: \(updatedTitle.status)")
            
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

// MARK: - Supporting Types
enum ReadingDirection: String, CaseIterable {
    case leftToRight = "leftToRight"
    case rightToLeft = "rightToLeft"
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
    
    
}// TitleView



#Preview {
    ContentView()
}


