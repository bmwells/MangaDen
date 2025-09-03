//
//  TitleView.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import SwiftUI

struct TitleView: View {
    let title: Title
    @State private var selectedChapter: Chapter?
    @State private var showOptionsMenu = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Cover Image with blurred edges
                    ZStack {
                        if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
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
                        Text(title.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("by \(title.author)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Status badge
                        HStack {
                            Spacer()
                            StatusBadge(status: title.status)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    .opacity(max(0, 1 - (-scrollOffset / 100)))
                    
                    Divider()
                    
                    // Chapters List
                    VStack(alignment: .leading, spacing: 8) {
                        if title.chapters.isEmpty {
                            Text("No chapters available")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(title.chapters) { chapter in
                                    NavigationLink(destination: ReaderView(chapter: chapter)) {
                                        ChapterRow(chapter: chapter)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
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
                        // Edit Title action
                    }) {
                        Label("Edit Title Info", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        // Download Title action
                    }) {
                        Label("Download Title", systemImage: "arrow.down.circle")
                    }
                    
                    Button(action: {
                        // Archive Title action
                    }) {
                        Label("Archive Title", systemImage: "archivebox")
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
            
            // Dismiss the view and go back to library
            dismiss()
            
        } catch {
            print("Error deleting title: \(error)")
        }
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
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

struct ChapterRow: View {
    let chapter: Chapter
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Combined chapter number and title on first line
                if let title = chapter.title, !title.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(chapter.formattedChapterNumber):  ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.light) // Lighter weight for title
                    }
                } else {
                    Text("Chapter \(chapter.formattedChapterNumber)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Upload date on second line
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                        .padding(.top, 5)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .contentShape(Rectangle()) // Makes the whole area tappable
    }
}
