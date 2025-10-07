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
    
    var body: some View {
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
}

// MARK: - Manage Mode Controls
struct ManageModeControls: View {
    let title: Title
    @Binding var manageMode: ManageMode
    @Binding var showManageMode: Bool
    @Binding var showUninstallAllConfirmation: Bool
    
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
    
    var body: some View {
        HStack {
            Text("Reading direction:")
                .font(.system(size: 16))
                .foregroundColor(.primary)

            HStack(spacing: 0) {

                Button(action: {
                    readingDirection = .rightToLeft
                    onDirectionChanged()
                }) {
                    HStack(spacing: 4) {
                        Text("L")
                            .font(.system(size: readingDirection == .rightToLeft ? 18 : 12))
                        
                        Text("←")
                            .font(.system(size: readingDirection == .rightToLeft ? 28 : 22)) // Larger arrow
                        
                        Text("R")
                            .font(.system(size: readingDirection == .rightToLeft ? 18 : 12))
                    }
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
                Button(action: {
                    readingDirection = .leftToRight
                    onDirectionChanged()
                }) {
                    HStack(spacing: 4) {
                        Text("L")
                            .font(.system(size: readingDirection == .leftToRight ? 18 : 12))
                        
                        Text("→")
                            .font(.system(size: readingDirection == .leftToRight ? 28 : 22)) // Larger arrow
                        
                        Text("R")
                            .font(.system(size: readingDirection == .leftToRight ? 18 : 12))
                    }
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
            }
            .background(Color.blue.opacity(0.05))
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
                            onRead: { onMarkAsRead(chapter) }
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
                
                // Status Picker Section
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
    
    var body: some View {
        Menu {
            Button(action: onRefresh) {
                Label("Refresh Title", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
            
            Button(action: onEdit) {
                Label("Edit Title Info", systemImage: "pencil")
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
    }
    
    private func archiveButtonText() -> String {
        return title.isArchived ? "Move to Reading" : "Archive Title"
    }

    private func archiveButtonIcon() -> String {
        return title.isArchived ? "book" : "archivebox"
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
        onDeleteChapter: @escaping (Chapter) -> Void
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
                Button("Uninstall All", role: .destructive) {
                    // Handled in TitleView
                }
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
