//
//  TitleComponents.swift
//  MangaDen
//
//  Created by Brody Wells on 10/1/25.
//

import SwiftUI
import PhotosUI

// MARK: - Cover Image Section
struct TitleCoverImageSection: View {
    let title: Title
    let scrollOffset: CGFloat
    @Binding var selectedCoverImage: UIImage?
    let geometry: GeometryProxy
    
    var body: some View {
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
}

// MARK: - Title Info Section
struct TitleInfoSection: View {
    let title: Title
    let editedTitle: String
    let editedAuthor: String
    let editedStatus: String
    let scrollOffset: CGFloat
    
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if !title.downloadedChapters.isEmpty {
                Text("\(title.downloadedChapters.count) Chapter\(title.downloadedChapters.count == 1 ? "" : "s") Downloaded [\(title.formattedDownloadSize)]")
                    .font(.subheadline)
                    .foregroundColor(currentAccentColor)
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
}

// MARK: - Download Mode Controls
struct DownloadModeControls: View {
    let title: Title
    @Binding var showDownloadMode: Bool
    @StateObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        HStack {
            Button("Download All") {
                downloadManager.downloadAllChapters(chapters: title.chapters, titleId: title.id)
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.chapters.allSatisfy { $0.safeIsDownloaded })
            
            Spacer()
            
            Button("Done") {
                withAnimation {
                    showDownloadMode = false
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(30)
    }
}

// MARK: - Manage Mode Controls
struct ManageModeControls: View {
    let title: Title
    @Binding var manageMode: ManageMode
    @Binding var showManageMode: Bool
    @Binding var showUninstallAllConfirmation: Bool
    let onUninstallAll: () -> Void
    
    var body: some View {
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
                            Text("Uninstall ALL Downloaded Chapters")
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
}

// MARK: - Reading Direction Selector
struct ReadingDirectionSelector: View {
    @Binding var readingDirection: ReadingDirection
    let onDirectionChanged: () -> Void
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 0) {

                Button(action: {
                    readingDirection = .rightToLeft
                    onDirectionChanged()
                }) {
                    HStack(spacing: 4) {
                        Text("L")
                            .font(.system(size: readingDirection == .rightToLeft ? 18 : 12))
                        
                        Text("←")
                            .font(.system(size: readingDirection == .rightToLeft ? 28 : 22))
                        
                        Text("R")
                            .font(.system(size: readingDirection == .rightToLeft ? 18 : 12))
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(readingDirection == .rightToLeft ? .white : currentAccentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(readingDirection == .rightToLeft ? currentAccentColor : currentAccentColor.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentAccentColor, lineWidth: 2)
                    )
                }
                Button(action: {
                    readingDirection = .leftToRight
                    onDirectionChanged()
                }) {
                    HStack(spacing: 4) {
                        Text("L")
                            .font(.system(size: readingDirection == .leftToRight ? 18 : 12))
                        
                        Text("→")
                            .font(.system(size: readingDirection == .leftToRight ? 28 : 22)) 
                        
                        Text("R")
                            .font(.system(size: readingDirection == .leftToRight ? 18 : 12))
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(readingDirection == .leftToRight ? .white : currentAccentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(readingDirection == .leftToRight ? currentAccentColor : currentAccentColor.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(currentAccentColor, lineWidth: 2)
                    )
                }
            }
            .background(currentAccentColor.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
        .padding(.horizontal)
    }
}
// MARK: - Chapters List Section
struct ChaptersListSection: View {
    let displayChapters: [Chapter]
    let readingDirection: ReadingDirection
    let showDownloadMode: Bool
    let showManageMode: Bool
    let onDeleteChapter: (Chapter) -> Void
    let onMarkAsRead: (Chapter) -> Void
    let titleID: UUID
    
    var body: some View {
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
                            onDelete: { onDeleteChapter(chapter) },
                            onDownload: { DownloadManager.shared.addToDownloadQueue(chapter: chapter) },
                            onRead: { onMarkAsRead(chapter) },
                            titleID: titleID
                        )
                        .id(chapter.id)
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
}


// MARK: - Edit Title Component
struct EditTitleView: View {
    let title: Title
    @Binding var editedTitle: String
    @Binding var editedAuthor: String
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isAuthorFocused: Bool
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
    
    // Computed properties to break down complex expressions
    private var coverImage: some View {
        Group {
            if let selectedCoverImage = selectedCoverImage {
                coverImageContent(selectedCoverImage)
            } else if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                coverImageContent(uiImage)
            } else {
                placeholderCoverImage
            }
        }
    }
    
    private func coverImageContent(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 200)
            .cornerRadius(8)
    }
    
    private var placeholderCoverImage: some View {
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
    
    private var titleURLView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let urlString = title.sourceURL, !urlString.isEmpty,
               let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Spacer()
                        Text(urlString)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Text("No URL available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusButtons: some View {
        HStack(spacing: 0) {
            ForEach(statusOptions, id: \.1) { displayName, value, color in
                statusButton(displayName: displayName, value: value, color: color)
                
                if value != statusOptions.last?.1 {
                    Spacer().frame(width: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusButton(displayName: String, value: String, color: Color) -> some View {
        Button(action: {
            editedStatus = value
        }) {
            Text(displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(editedStatus == value ? .white : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background( Group { if editedStatus == value { color } else { color.opacity(0.1) } } )
                .cornerRadius(8) // Add corner radius to the background
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: editedStatus == value ? 0 : 2) // Hide stroke when selected
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Cover Image")) {
                    HStack {
                        Spacer()
                        coverImage
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
                    HStack {
                        TextField("Title", text: $editedTitle)
                            .focused($isTitleFocused)
                        if !editedTitle.isEmpty && isTitleFocused {
                            Button(action: { editedTitle = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    HStack {
                        TextField("Author (optional)", text: $editedAuthor)
                            .focused($isAuthorFocused)
                        if !editedAuthor.isEmpty && isAuthorFocused {
                            Button(action: { editedAuthor = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Status Picker Section
                Section(header: Text("Status")) {
                    statusButtons
                }
                
                // Title URL
                Section(header: Text("Title URL")) {
                    titleURLView
                }
            }
            .navigationTitle("Manage Title")
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
                    .disabled(editedTitle.isEmpty)
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
                // Set initial status
                if editedStatus.isEmpty {
                    editedStatus = title.status.lowercased()
                }
            }
        }
    }
}

// MARK: - Options Menu
struct OptionsMenu: View {
    let isRefreshing: Bool
    let title: Title
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onDownloadModeToggle: () -> Void
    let onManageModeToggle: () -> Void
    let onToggleArchive: () -> Void
    let onDelete: () -> Void
    @State private var showHelp = false
    
    var body: some View {
        Menu {
            // Help button
            Button(action: { showHelp = true }) {
                Label("Help", systemImage: "questionmark.circle")
            }
            
            Button(action: onRefresh) {
                Label("Refresh Title", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
            
            Button(action: onEdit) {
                Label("Manage Title", systemImage: "square.and.pencil")
            }
            
            Button(action: onDownloadModeToggle) {
                Label("Download Chapters", systemImage: "arrow.down.circle")
            }
            
            Button(action: onManageModeToggle) {
                Label("Manage Chapters", systemImage: "list.dash")
            }
            
            Button(action: onToggleArchive) {
                Label(archiveButtonText(), systemImage: archiveButtonIcon())
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete Title", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
        }
        .sheet(isPresented: $showHelp) {
            TitleHelpView()
        }
    }
    
    private func archiveButtonText() -> String {
        return title.isArchived ? "Move to Reading" : "Archive Title"
    }

    private func archiveButtonIcon() -> String {
        return title.isArchived ? "book" : "archivebox"
    }
}


// MARK: - Title Help View
struct TitleHelpView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title Guide
                    Text("Title Guide")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 20)
                    
                    Text("**Refresh Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Checks for new chapters.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.system(size: 20))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Manage Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Modify the title, author, status, or cover image.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Download Chapters**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Download multiple chapters for offline reading.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Manage Chapters**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Uninstall downloaded chapters or hide chapters from the list.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Archive Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Moves the title from the Reading section to the Archive section.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 18))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    Text("**Delete Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Permanently removes the title from your library.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .font(.system(size: 18))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    
                    // Reader Guide
                    Text("Reader Guide")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 20)
                    
                    HStack(spacing: 8) {
                        Text("**Zoom Button**")
                            .font(.title3)
                            .italic()
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("Enables zoom gestures for current page. Pinch page with two fingers to zoom in or out. Drag with one finger to move around image. To exit either double tap or zoom out (pinch in) till zoom mode is exited.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20))
                        .padding(.top, 4)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 8) {
                        Text("**Download Image Button**")
                            .font(.title3)
                            .italic()
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("Download current panel image to camera roll.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 20))
                        .padding(.top, 4)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    // Tip
                    Text("Tips:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Clean up bad chapter links by hiding them within the 'Manage Chapters' option")
                        .font(.system(size: 18))
                        .tracking(1.0)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                        .font(.system(size: 18))
                        .tracking(1.0)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 15)
            .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}



// MARK: - Status Badge
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

// MARK: - View Extensions for Alerts and Overlays
extension View {
    func alerts(
        showDeleteConfirmation: Binding<Bool>,
        showDeleteChapterConfirmation: Binding<Bool>,
        showUninstallAllConfirmation: Binding<Bool>,
        showRefreshResult: Binding<Bool>,
        manageMode: ManageMode,
        chapterToDelete: Chapter?,
        title: Title,
        refreshResultMessage: String,
        onDeleteTitle: @escaping () -> Void,
        onDeleteChapter: @escaping (Chapter) -> Void,
        onUninstallAll: @escaping () -> Void
        
    ) -> some View {
        self
            .alert("Delete Title", isPresented: showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive, action: onDeleteTitle)
            } message: {
                Text("Are you sure you want to delete \"\(title.title)\" from your library? This action cannot be undone.")
            }
            .alert(manageMode == .hideFromList ? "Hide Chapter" : "Uninstall Chapter", isPresented: showDeleteChapterConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(manageMode == .hideFromList ? "Hide" : "Uninstall", role: .destructive) {
                    if let chapter = chapterToDelete {
                        onDeleteChapter(chapter)
                    }
                }
            } message: {
                if let chapter = chapterToDelete {
                    Text("Are you sure you want to \(manageMode == .hideFromList ? "hide" : "uninstall") \"\(chapter.title ?? "Chapter \(chapter.formattedChapterNumber)")\"?")
                }
            }
            .alert("Uninstall All Downloaded Chapters", isPresented: showUninstallAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall All", role: .destructive, action: onUninstallAll)
            } message: {
                Text("Are you sure you want to uninstall ALL downloaded chapters for \"\(title.title)\"? This will remove all downloaded content and cannot be undone.")
            }
            .alert("Refresh Complete", isPresented: showRefreshResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(refreshResultMessage)
            }
    }
    
    func refreshOverlay(isRefreshing: Bool) -> some View {
        self.overlay {
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
}



#Preview {
    ContentView()
}

