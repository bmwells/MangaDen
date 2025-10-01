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
                    coverImageSection(geometry: geometry)
                    titleInfoSection
                    
                    if showDownloadMode {
                        downloadModeControls
                    }
                    
                    if showManageMode {
                        manageModeControls
                    }
                    
                    if !showDownloadMode && !showManageMode {
                        readingDirectionSelector
                    }
                    
                    Divider()
                    chaptersListSection
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
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                optionsMenu
            }
        }
        // Apply the alerts and overlays directly
        .alert("Delete Title", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteTitle)
        } message: {
            Text("Are you sure you want to delete \"\(title.title)\" from your library? This action cannot be undone.")
        }
        .alert(manageMode == .hideFromList ? "Hide Chapter" : "Uninstall Chapter", isPresented: $showDeleteChapterConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(manageMode == .hideFromList ? "Hide" : "Uninstall", role: .destructive) {
                if let chapter = chapterToDelete {
                    deleteChapter(chapter)
                }
            }
        } message: {
            if let chapter = chapterToDelete {
                Text("Are you sure you want to \(manageMode == .hideFromList ? "hide" : "uninstall") \"\(chapter.title ?? "Chapter \(chapter.formattedChapterNumber)")\"?")
            }
        }
        .alert("Uninstall All Chapters", isPresented: $showUninstallAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall All", role: .destructive, action: uninstallAllChapters)
        } message: {
            Text("Are you sure you want to uninstall ALL downloaded chapters for \"\(title.title)\"? This will remove all downloaded content and cannot be undone.")
        }
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
        .overlay {
            if isRefreshing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Refreshing...")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.8))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .alert("Refresh Complete", isPresented: $showRefreshResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(refreshResultMessage)
        }
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

    // MARK: - Alerts
    private var alerts: some View {
        EmptyView()
            .alert("Delete Title", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive, action: deleteTitle)
            } message: {
                Text("Are you sure you want to delete \"\(title.title)\" from your library? This action cannot be undone.")
            }
            .alert(manageMode == .hideFromList ? "Hide Chapter" : "Uninstall Chapter", isPresented: $showDeleteChapterConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(manageMode == .hideFromList ? "Hide" : "Uninstall", role: .destructive) {
                    if let chapter = chapterToDelete {
                        deleteChapter(chapter)
                    }
                }
            } message: {
                if let chapter = chapterToDelete {
                    Text("Are you sure you want to \(manageMode == .hideFromList ? "hide" : "uninstall") \"\(chapter.title ?? "Chapter \(chapter.formattedChapterNumber)")\"?")
                }
            }
            .alert("Uninstall All Chapters", isPresented: $showUninstallAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall All", role: .destructive, action: uninstallAllChapters)
            } message: {
                Text("Are you sure you want to uninstall ALL downloaded chapters for \"\(title.title)\"? This will remove all downloaded content and cannot be undone.")
            }
    }

    // MARK: - Refresh Overlay
    private var refreshOverlay: some View {
        EmptyView()
            .overlay {
                if isRefreshing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Refreshing...")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.8))
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
    }

    // MARK: - Refresh Alert
    private var refreshAlert: some View {
        EmptyView()
            .alert("Refresh Complete", isPresented: $showRefreshResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(refreshResultMessage)
            }
    }
    
    
    // MARK: - View Components
    
    private func coverImageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            if let selectedCoverImage = selectedCoverImage {
                backgroundCoverImage(selectedCoverImage, geometry: geometry)
                foregroundCoverImage(selectedCoverImage)
            } else if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                backgroundCoverImage(uiImage, geometry: geometry)
                foregroundCoverImage(uiImage)
            } else {
                placeholderCoverImage(geometry: geometry)
            }
        }
        .frame(height: 300)
    }
    
    private func backgroundCoverImage(_ image: UIImage, geometry: GeometryProxy) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: 300 + max(0, -scrollOffset))
            .clipped()
            .blur(radius: 10)
            .scaleEffect(1.05)
            .offset(y: min(0, scrollOffset * 0.5))
    }
    
    private func foregroundCoverImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(height: 300)
            .cornerRadius(12)
            .shadow(radius: 5)
            .padding(.horizontal)
            .offset(y: min(0, scrollOffset * 0.5))
    }
    
    private func placeholderCoverImage(geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: geometry.size.width, height: 300 + max(0, -scrollOffset))
            .clipped()
            .offset(y: min(0, scrollOffset * 0.5))
            .overlay(
                Text(title.title.prefix(1))
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            )
    }
    
    private var titleInfoSection: some View {
        VStack(spacing: 8) {
            if !title.downloadedChapters.isEmpty {
                Text("\(title.downloadedChapters.count) Chapter\(title.downloadedChapters.count == 1 ? "" : "s") Downloaded [\(title.formattedDownloadSize)]")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                    .padding(.top, 4)
            }
            
            Text(editedTitle.isEmpty ? title.title : editedTitle)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if !(editedAuthor.isEmpty ? title.author : editedAuthor).isEmpty {
                Text("by \(editedAuthor.isEmpty ? title.author : editedAuthor)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                StatusBadge(status: editedStatus.isEmpty ? title.status : editedStatus)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .opacity(max(0, 1 - (-scrollOffset / 100)))
    }
    
    private var downloadModeControls: some View {
        HStack {
            Button("Download All") {
                downloadManager.downloadAllChapters(chapters: title.chapters)
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.chapters.allSatisfy { $0.isDownloaded })
            
            Spacer()
            
            Button("Done") {
                withAnimation {
                    showDownloadMode = false
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var manageModeControls: some View {
        VStack(spacing: 12) {
            if !title.downloadedChapters.isEmpty {
                Button(action: {
                    withAnimation {
                        manageMode = .uninstallDownloaded
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Uninstall Downloaded Chapters")
                        Spacer()
                        if manageMode == .uninstallDownloaded {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .foregroundColor(manageMode == .uninstallDownloaded ? .blue : .primary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                if manageMode == .uninstallDownloaded {
                    Button(role: .destructive, action: {
                        showUninstallAllConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Uninstall ALL Chapters")
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            
            Button(action: {
                withAnimation {
                    manageMode = .hideFromList
                }
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Hide Chapters in List")
                    Spacer()
                    if manageMode == .hideFromList {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(manageMode == .hideFromList ? .blue : .primary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Button(action: {
                withAnimation {
                    showManageMode = false
                    manageMode = !title.downloadedChapters.isEmpty ? .uninstallDownloaded : .hideFromList
                }
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Done")
                    Spacer()
                }
                .foregroundColor(.green)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var readingDirectionSelector: some View {
        HStack {
            Text("Reading direction:")
                .font(.system(size: 16))
                .foregroundColor(.primary)

            
            HStack(spacing: 0) {
                Button(action: {
                    readingDirection = .leftToRight
                    saveReadingDirection()
                }) {
                    Text("L → R")
                        .font(.system(size: readingDirection == .leftToRight ? 18 : 12))
                        .fontWeight(.semibold)
                        .foregroundColor(readingDirection == .leftToRight ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(readingDirection == .leftToRight ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }

                Button(action: {
                    readingDirection = .rightToLeft
                    saveReadingDirection()
                }) {
                    Text("L ← R")
                        .font(.system(size: readingDirection == .rightToLeft ? 18 : 12))
                        .fontWeight(.semibold)
                        .foregroundColor(readingDirection == .rightToLeft ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(readingDirection == .rightToLeft ? Color.blue : Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
            }
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .padding(.horizontal)
    }
    
    private var chaptersListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if displayChapters.isEmpty {
                Text("No chapters available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayChapters) { chapter in
                        ChapterRowView(
                            chapter: chapter,
                            readingDirection: readingDirection,
                            showDownloadMode: showDownloadMode,
                            showManageMode: showManageMode,
                            onDelete: { chapterToDelete = chapter; showDeleteChapterConfirmation = true },
                            onDownload: { downloadManager.addToDownloadQueue(chapter: chapter) },
                            onRead: { markChapterAsRead(chapter: chapter) }
                        )
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
    
    private var optionsMenu: some View {
        Menu {
            Button(action: refreshTitle) {
                Label("Refresh Title", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
            
            Button(action: { showEditSheet = true }) {
                Label("Edit Title Info", systemImage: "pencil")
            }
            
            Button(action: {
                withAnimation {
                    showDownloadMode.toggle()
                    if showDownloadMode { showManageMode = false }
                }
            }) {
                Label("Download Chapters", systemImage: "arrow.down.circle")
            }
            
            Button(action: {
                withAnimation {
                    showManageMode.toggle()
                    if showManageMode { showDownloadMode = false }
                }
            }) {
                Label("Manage Chapters", systemImage: "list.dash")
            }
            
            Button(action: toggleArchiveStatus) {
                Label(archiveButtonText(), systemImage: archiveButtonIcon())
            }
            
            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete Title", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
        }
    }
    
  
    // MARK: - Helper Views
    
    private struct ChapterRowView: View {
        let chapter: Chapter
        let readingDirection: ReadingDirection
        let showDownloadMode: Bool
        let showManageMode: Bool
        let onDelete: () -> Void
        let onDownload: () -> Void
        let onRead: () -> Void
        
        @StateObject private var downloadManager = DownloadManager.shared
        
        private var isInQueue: Bool {
            downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
        }
        
        private var isDownloaded: Bool {
            chapter.isDownloaded
        }
        
        var body: some View {
            HStack {
                if showDownloadMode {
                    Button(action: onDownload) {
                        Image(systemName: isDownloaded || isInQueue ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(isDownloaded || isInQueue ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isDownloaded || isInQueue)
                }
                
                if showManageMode {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                NavigationLink(
                    destination: ReaderView(chapter: chapter, readingDirection: readingDirection)
                ) {
                    ChapterRowContent(
                        chapter: chapter,
                        showDownloadButton: showDownloadMode,
                        showManageMode: showManageMode
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded(onRead))
            }
        }
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
            // Hide chapter from list by adding to hidden URLs
            hiddenChapterURLs.insert(chapter.url)
            saveHiddenChapters()
            
        case .uninstallDownloaded:
            // Remove downloaded chapter from storage
            uninstallChapter(chapter)
        }
        
        // Notify for refresh
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
            
            // Notify for refresh
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
            
            // Notify for refresh
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
                
                // Notify LibraryView to refresh
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
            
            // Notify LibraryView to refresh
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
            // Show tab bar and dismiss
            tabBarManager.isTabBarHidden = false
            dismiss()
            
        } catch {
            print("Error updating archive status: \(error)")
        }
    }

    private func archiveButtonText() -> String {
        return title.isArchived ? "Move to Reading" : "Archive Title"
    }

    private func archiveButtonIcon() -> String {
        return title.isArchived ? "book" : "archivebox"
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
            
            // Notify LibraryView to refresh
            NotificationCenter.default.post(name: .titleDeleted, object: nil)
            
            // Show tab bar and dismiss
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
            print("Updated title info: \(updatedTitle.title) by \(updatedTitle.author) with status: \(updatedTitle.status)") // UPDATED
            
            // Notify LibraryView to refresh
            NotificationCenter.default.post(name: .titleUpdated, object: nil)
            
        } catch {
            print("Error saving title changes: \(error)")
        }
    }
}

// MARK: - ChapterRow with download button and read status (UPDATED)
struct ChapterRow: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    let onDownloadTapped: () -> Void
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        HStack {
            if showDownloadButton {
                Button(action: onDownloadTapped) {
                    Image(systemName: isDownloaded || isInQueue ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(isDownloaded || isInQueue ? .green : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDownloaded || isInQueue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Combined chapter number and title on first line
                if let title = chapter.title, !title.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(chapter.formattedChapterNumber):  ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(chapter.isRead ? .gray : .primary)
                }
                
                // Upload date on second line
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, showDownloadButton ? 0 : 20)
                        .padding(.top, 5)
                }
            }
            
            Spacer()
            
            if isInQueue {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}


// MARK: - Updated ChapterRowContent
struct ChapterRowContent: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    let showManageMode: Bool
    
    @StateObject private var downloadManager = DownloadManager.shared
    
    private var isInQueue: Bool {
        downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id }
    }
    
    private var isDownloaded: Bool {
        chapter.isDownloaded
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Combined chapter number and title on first line
                if let title = chapter.title, !title.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(chapter.formattedChapterNumber):  ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .foregroundColor(chapter.isRead ? .gray : .primary)
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(chapter.isRead ? .gray : .primary)
                }
                
                // Upload date on second line
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, showDownloadButton ? 0 : 20)
                        .padding(.top, 5)
                }
            }
            
            Spacer()
            
            if isInQueue {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle())
    }
}











// MARK: - Other ENUM and STRUCT

enum ReadingDirection: String, CaseIterable {
    case leftToRight = "L→R"
    case rightToLeft = "L←R"
}

enum ManageMode {
    case uninstallDownloaded
    case hideFromList
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.headline)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(12)
            
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "completed": return .green
        case "releasing": return .blue
        case "hiatus": return .orange
        case "dropped": return .red
        default: return .gray
        }
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}





// MARK: - EDIT TITLE VIEW
struct EditTitleView: View {
    let title: Title
    @Binding var editedTitle: String
    @Binding var editedAuthor: String
    @Binding var editedStatus: String
    @Binding var selectedCoverImage: UIImage?
    @Binding var coverImageItem: PhotosPickerItem?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    let statusOptions = [
        ("Releasing", "releasing", Color.blue),
        ("Completed", "completed", Color.green),
        ("Hiatus", "hiatus", Color.orange)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Cover Image")) {
                    HStack {
                        Spacer()
                        if let selectedCoverImage = selectedCoverImage {
                            Image(uiImage: selectedCoverImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 200)
                                .cornerRadius(8)
                        } else if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 200)
                                .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 150, height: 200)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                )
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    PhotosPicker(selection: $coverImageItem, matching: .images) {
                        Label("Change Cover Image", systemImage: "photo")
                    }
                    
                    if selectedCoverImage != nil {
                        Button(role: .destructive) {
                            selectedCoverImage = nil
                            coverImageItem = nil
                        } label: {
                            Label("Remove Cover Image", systemImage: "trash")
                        }
                    }
                }
                
                Section(header: Text("Title Information")) {
                    TextField("Title", text: $editedTitle)
                    TextField("Author (optional)", text: $editedAuthor)
                }
                
                // Status Picker Section - UPDATED to use binding
                Section(header: Text("Status")) {
                    HStack(spacing: 0) {
                        ForEach(statusOptions, id: \.1) { displayName, value, color in
                            Button(action: {
                                editedStatus = value
                            }) {
                                Text(displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(editedStatus == value ? .white : color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(editedStatus == value ? color : color.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(color, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if value != statusOptions.last?.1 {
                                Spacer().frame(width: 8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
            }
            .navigationTitle("Edit Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(editedTitle.isEmpty) // Only require title, not author
                }
            }
            .onChange(of: coverImageItem) { oldItem, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedCoverImage = image
                    }
                }
            }
            .onAppear {
                if editedTitle.isEmpty {
                    editedTitle = title.title
                }
                if editedAuthor.isEmpty {
                    editedAuthor = title.author
                }
                // Set initial status - UPDATED
                if editedStatus.isEmpty {
                    editedStatus = title.status.lowercased()
                }
            }
        }
    }
    

}// TitleView



#Preview {
    ContentView()
}


