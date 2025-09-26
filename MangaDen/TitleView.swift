import SwiftUI
import PhotosUI

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
    @State private var selectedCoverImage: UIImage?
    @State private var coverImageItem: PhotosPickerItem?
    @State private var showDownloadMode = false
    @Environment(\.dismiss) private var dismiss
    
    // Filter chapters based on current tab
    var displayChapters: [Chapter] {
        if title.isDownloaded {
            return title.downloadedChapters
        } else {
            return title.chapters
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Cover Image with blurred edges
                    ZStack {
                        if let selectedCoverImage = selectedCoverImage {
                            Image(uiImage: selectedCoverImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 300 + max(0, -scrollOffset))
                                .clipped()
                                .blur(radius: 10)
                                .scaleEffect(1.05)
                                .offset(y: min(0, scrollOffset * 0.5))
                            
                            Image(uiImage: selectedCoverImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 300)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal)
                                .offset(y: min(0, scrollOffset * 0.5))
                        } else if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 300 + max(0, -scrollOffset))
                                .clipped()
                                .blur(radius: 10)
                                .scaleEffect(1.05)
                                .offset(y: min(0, scrollOffset * 0.5))
                            
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 300)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal)
                                .offset(y: min(0, scrollOffset * 0.5))
                        } else {
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
                    }
                    .frame(height: 300)
                    
                    // Title and Author (will be hidden when scrolling)
                    VStack(spacing: 8) {
                        
                        
                        
                        // Download info for downloaded titles
                        if !title.downloadedChapters.isEmpty {
                            Text("\(title.downloadedChapters.count) Chapter\(title.downloadedChapters.count == 1 ? "" : "s") Downloaded [\(title.formattedDownloadSize)]")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                                .padding(.top, 4)
                        }
                        
                        Text(editedTitle.isEmpty ? title.title : editedTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("by \(editedAuthor.isEmpty ? title.author : editedAuthor)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    
                        
                        // Status badge
                        HStack {
                            Spacer()
                            StatusBadge(status: title.status)
                            Spacer()
                        }
                        .padding(.top, 4)
                        
                        
                        // Download Mode Controls
                        if showDownloadMode {
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
                        
                        // Reading Direction Selector
                        HStack {
                            Text("Reading direction:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    readingDirection = .leftToRight
                                    saveReadingDirection()
                                }) {
                                    Text("L→R")
                                        .font(.subheadline)
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
                                    Text("L←R")
                                        .font(.subheadline)
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
                        .padding(.horizontal)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    .opacity(max(0, 1 - (-scrollOffset / 100)))
                    
                    Divider()
                    
                    // Chapters List
                    VStack(alignment: .leading, spacing: 8) {
                        if displayChapters.isEmpty {
                            Text("No chapters available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(displayChapters) { chapter in
                                    HStack {
                                        if showDownloadMode {
                                            Button(action: {
                                                downloadManager.addToDownloadQueue(chapter: chapter)
                                            }) {
                                                Image(systemName: chapter.isDownloaded || downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id } ? "checkmark.circle.fill" : "plus.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(chapter.isDownloaded || downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id } ? .green : .blue)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .disabled(chapter.isDownloaded || downloadManager.downloadQueue.contains { $0.chapter.id == chapter.id })
                                        }
                                        
                                        NavigationLink(
                                            destination: ReaderView(chapter: chapter, readingDirection: readingDirection)
                                                .environmentObject(tabBarManager)
                                        ) {
                                            ChapterRowContent(
                                                chapter: chapter,
                                                showDownloadButton: showDownloadMode
                                            )
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .simultaneousGesture(TapGesture().onEnded {
                                            markChapterAsRead(chapter: chapter)
                                        })
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
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
                Menu {
                    Button(action: {
                        // Refresh Title action
                    }) {
                        Label("Refresh Title", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        showEditSheet = true
                    }) {
                        Label("Edit Title Info", systemImage: "pencil")
                    }
                    
                    if title.isDownloaded {
                        Button(role: .destructive, action: {
                            removeDownloadedChapters()
                        }) {
                            Label("Remove Chapters", systemImage: "trash")
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                showDownloadMode.toggle()
                            }
                        }) {
                            Label("Download Title", systemImage: "arrow.down.circle")
                        }
                    }
                    
                    Button(action: {
                        toggleArchiveStatus()
                    }) {
                        Label(archiveButtonText(), systemImage: archiveButtonIcon())
                    }
                    
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Title", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
            }
        }
        .alert("Delete Title", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTitle()
            }
        } message: {
            Text("Are you sure you want to delete \"\(title.title)\" from your library? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditTitleView(
                title: title,
                editedTitle: $editedTitle,
                editedAuthor: $editedAuthor,
                selectedCoverImage: $selectedCoverImage,
                coverImageItem: $coverImageItem,
                onSave: saveTitleChanges
            )
        }
        .onAppear {
            loadReadingDirection()
            editedTitle = title.title
            editedAuthor = title.author
            tabBarManager.isTabBarHidden = true
            print("TitleView appeared - Tab bar hidden: \(tabBarManager.isTabBarHidden)")
        }
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
    
    private func removeDownloadedChapters() {
        // Implementation for removing downloaded chapters
        // This would delete the downloaded files and update the title
        print("Remove downloaded chapters functionality to be implemented")
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
            
            // Update cover image if changed
            if let newCoverImage = selectedCoverImage {
                updatedTitle.coverImageData = newCoverImage.jpegData(compressionQuality: 0.8)
            }
            
            // Save the updated title
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
            
            let titleData = try JSONEncoder().encode(updatedTitle)
            try titleData.write(to: titleFile)
            print("Updated title info: \(updatedTitle.title) by \(updatedTitle.author)")
            
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

struct ChapterRowContent: View {
    let chapter: Chapter
    let showDownloadButton: Bool
    
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

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            
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
    @Binding var selectedCoverImage: UIImage?
    @Binding var coverImageItem: PhotosPickerItem?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
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
                    TextField("Author", text: $editedAuthor)
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
                    .disabled(editedTitle.isEmpty || editedAuthor.isEmpty)
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
            }
        }
    }
}


