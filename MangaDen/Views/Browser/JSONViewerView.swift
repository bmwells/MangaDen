//
//  JSONViewerView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/29/25.
//

import SwiftUI

struct JSONViewerView: View {
    @State private var jsonContent: String = "Loading..."
    @State private var isLoading = true
    @State private var chapters: [Chapter] = []
    @State private var mangaMetadata: [String: Any]? = nil
    @State private var showingMetadata = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Manga Metadata Header
                if let metadata = mangaMetadata {
                    MangaMetadataHeader(metadata: metadata, showingMetadata: $showingMetadata)
                        .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView("Loading JSON data...")
                        .padding()
                } else if chapters.isEmpty {
                    Text("No JSON data found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(chapters) { chapter in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(chapter.formattedChapterNumber)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                            }
                            
                            if let title = chapter.title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let uploadDate = chapter.uploadDate, !uploadDate.isEmpty {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    Text(uploadDate)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text(chapter.url)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Manga Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy All") {
                        UIPasteboard.general.string = jsonContent
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadJSON()
                        loadMangaMetadata()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(chapters.count) chapters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                loadJSON()
                loadMangaMetadata()
            }
            .sheet(isPresented: $showingMetadata) {
                if let metadata = mangaMetadata {
                    MangaMetadataDetailView(metadata: metadata)
                }
            }
        }
    }
    
    private func loadJSON() {
        isLoading = true
        chapters = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("chapters.json")
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        // Parse the JSON array into Chapter objects using the new struct
                        if let jsonArray = jsonObject as? [[String: Any]] {
                            var parsedChapters: [Chapter] = []
                            
                            for chapterDict in jsonArray {
                                if let chapter = parseChapter(from: chapterDict) {
                                    parsedChapters.append(chapter)
                                }
                            }
                            
                            // Sort chapters by chapter number (descending)
                            parsedChapters.sort { $0.chapterNumber > $1.chapterNumber }
                            
                            let prettyData = try JSONSerialization.data(withJSONObject: jsonArray, options: [.prettyPrinted])
                            let jsonString = String(data: prettyData, encoding: .utf8) ?? "Failed to decode JSON"
                            
                            DispatchQueue.main.async {
                                self.chapters = parsedChapters
                                self.jsonContent = jsonString
                                self.isLoading = false
                            }
                            return
                        }
                    } catch {
                        print("Error loading JSON: \(error)")
                        DispatchQueue.main.async {
                            self.jsonContent = "Error loading JSON: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.jsonContent = "No JSON data found"
                self.isLoading = false
            }
        }
    }
    
    private func parseChapter(from dict: [String: Any]) -> Chapter? {
        guard let chapterNumber = dict["chapter_number"] as? Double,
              let url = dict["url"] as? String else {
            return nil
        }
        
        return Chapter(
            chapterNumber: chapterNumber,
            url: url,
            title: dict["title"] as? String,
            uploadDate: dict["upload_date"] as? String,
            isDownloaded: false,
            isRead: false,
            downloadProgress: 0.0,
            totalImages: 0,
            downloadedImages: 0
        )
    }
    
    private func loadMangaMetadata() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let metadata = loadMangaMetadataFromFile() {
                DispatchQueue.main.async {
                    self.mangaMetadata = metadata
                }
            }
        }
    }
    
    private func loadMangaMetadataFromFile() -> [String: Any]? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let metadataFile = documentsDirectory.appendingPathComponent("manga_metadata.json")
        
        if FileManager.default.fileExists(atPath: metadataFile.path) {
            do {
                let data = try Data(contentsOf: metadataFile)
                let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                return metadata
            } catch {
                print("Error loading manga metadata: \(error)")
            }
        }
        
        return nil
    }
}

// Manga Metadata Header View
struct MangaMetadataHeader: View {
    let metadata: [String: Any]
    @Binding var showingMetadata: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title at the top
            if let title = metadata["title"] as? String {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                if let imageUrl = metadata["title_image"] as? String,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let author = metadata["author"] as? String {
                        Text("By \(author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let status = metadata["status"] as? String {
                        HStack {
                            Image(systemName: status == "completed" ? "checkmark.circle.fill" :
                                  status == "releasing" ? "arrow.clockwise" :
                                  status == "hiatus" ? "pause.circle" : "xmark.circle")
                                .foregroundColor(
                                    status == "completed" ? .green :
                                    status == "releasing" ? .blue :
                                    status == "hiatus" ? .orange : .red
                                )
                            Text(status.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// Manga Metadata Detail View
struct MangaMetadataDetailView: View {
    let metadata: [String: Any]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title at the top of detail view
                    if let title = metadata["title"] as? String {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if let imageUrl = metadata["title_image"] as? String,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300, maxHeight: 400)
                                .cornerRadius(12)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 300, height: 400)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    }
                    
                    VStack(spacing: 16) {
                        if let author = metadata["author"] as? String {
                            HStack {
                                Text("Author:")
                                    .fontWeight(.bold)
                                    .frame(width: 80, alignment: .leading)
                                Text(author)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        
                        if let status = metadata["status"] as? String {
                            HStack {
                                Text("Status:")
                                    .fontWeight(.bold)
                                    .frame(width: 80, alignment: .leading)
                                Text(status.capitalized)
                                    .foregroundColor(
                                        status == "completed" ? .green :
                                        status == "releasing" ? .blue :
                                        status == "hiatus" ? .orange : .red
                                    )
                                Image(systemName: status == "completed" ? "checkmark.circle.fill" :
                                      status == "releasing" ? "arrow.clockwise" :
                                      status == "hiatus" ? "pause.circle" : "xmark.circle")
                                    .foregroundColor(
                                        status == "completed" ? .green :
                                        status == "releasing" ? .blue :
                                        status == "hiatus" ? .orange : .red
                                    )
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding()
            }
            .navigationTitle("Manga Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct JSONViewerView_Previews: PreviewProvider {
    static var previews: some View {
        JSONViewerView()
    }
}
