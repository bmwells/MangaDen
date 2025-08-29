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
    
    var body: some View {
        NavigationView {
            VStack {
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
                                Text("Chapter \(chapter.formattedChapterNumber)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = chapter.url
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let title = chapter.title, !title.isEmpty {
                                Text(title)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                        
                        // Parse the JSON array into Chapter objects
                        if let jsonArray = jsonObject as? [[String: Any]] {
                            var parsedChapters: [Chapter] = []
                            
                            for chapterDict in jsonArray {
                                if let chapter = Chapter(from: chapterDict) {
                                    parsedChapters.append(chapter)
                                }
                            }
                            
                            // The JSON is already in descending order, so we can use it as-is
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
}

// Chapter model to represent the JSON structure
struct Chapter: Identifiable {
    let id = UUID()
    let chapterNumber: Double
    let url: String
    let title: String?
    
    var formattedChapterNumber: String {
        // Remove trailing .0 if it's a whole number
        if chapterNumber.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", chapterNumber)
        } else {
            return String(chapterNumber)
        }
    }
    
    init?(from dict: [String: Any]) {
        guard let chapterNumber = dict["chapter_number"] as? Double,
              let url = dict["url"] as? String else {
            return nil
        }
        
        self.chapterNumber = chapterNumber
        self.url = url
        self.title = dict["title"] as? String
    }
}

struct JSONViewerView_Previews: PreviewProvider {
    static var previews: some View {
        JSONViewerView()
    }
}
