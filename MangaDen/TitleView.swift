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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cover Image
                if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            Text(title.title.prefix(1))
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        )
                }
                
                // Title and Author
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
                        StatusBadge(status: title.status)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Chapters List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chapters (\(title.chapters.count))")
                        .font(.headline)
                        .padding(.horizontal)
                    
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
        }
        .navigationTitle(title.title)
        .navigationBarTitleDisplayMode(.inline)
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
                Text("Chapter \(chapter.formattedChapterNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let title = chapter.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                    Text(uploadDate)
                        .font(.caption2)
                        .foregroundColor(.gray)
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


