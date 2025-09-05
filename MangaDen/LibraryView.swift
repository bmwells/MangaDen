//
//  LibraryView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

// MARK: - Title Struct
struct Title: Identifiable, Codable {
    let id: UUID
    let title: String
    let author: String
    let status: String
    let coverImageData: Data?
    let chapters: [Chapter]
    let metadata: [String: Any]
    var isDownloaded: Bool
    var isArchived: Bool
    
    // Coding keys to handle the metadata dictionary
    enum CodingKeys: String, CodingKey {
        case id, title, author, status, coverImageData, chapters, isDownloaded, isArchived, metadata
    }
    
    init(id: UUID = UUID(), title: String, author: String, status: String,
         coverImageData: Data?, chapters: [Chapter], metadata: [String: Any],
         isDownloaded: Bool = false, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.coverImageData = coverImageData
        self.chapters = chapters
        self.metadata = metadata
        self.isDownloaded = isDownloaded
        self.isArchived = isArchived
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(status, forKey: .status)
        try container.encode(coverImageData, forKey: .coverImageData)
        try container.encode(chapters, forKey: .chapters)
        try container.encode(isDownloaded, forKey: .isDownloaded)
        try container.encode(isArchived, forKey: .isArchived)
        
        // Encode metadata as JSON data
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])
        try container.encode(metadataData, forKey: .metadata)
    }
    
    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        status = try container.decode(String.self, forKey: .status)
        coverImageData = try container.decode(Data?.self, forKey: .coverImageData)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        isDownloaded = try container.decode(Bool.self, forKey: .isDownloaded)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        
        // Decode metadata from JSON data
        let metadataData = try container.decode(Data.self, forKey: .metadata)
        metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] ?? [:]
    }
}

// MARK: - Library Screen
struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .reading
    @State private var showAddManga: Bool = false
    @State private var titles: [Title] = []
    
    // Tabs (Reading, Downloads, Archive)
    enum LibraryTab: String, CaseIterable {
        case reading = "Reading"
        case downloads = "Downloads"
        case archive = "Archive"
    }
    
    // Tab Filters
    var filteredTitles: [Title] {
        let filtered: [Title]
        switch selectedTab {
        case .reading: filtered = titles.filter { !$0.isArchived }
        case .downloads: filtered = titles.filter { $0.isDownloaded }
        case .archive: filtered = titles.filter { $0.isArchived }
        }
        
        // Sort alphabetically by title
        return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: { showAddManga = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .medium))
                            .padding(8)
                            .offset(x:20, y:-15)
                    }
                    .sheet(isPresented: $showAddManga) { AddTitleView() }
                    
                    Spacer()
                    
                    Picker("", selection: $selectedTab) {
                        ForEach(LibraryTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .fixedSize()
                    .padding(.horizontal)
                    .scaleEffect(x: 0.9, y: 1.0) // Make 80% width, keep full height
                    .offset(y: -5)
                    
                    Spacer()
                    
                    // Add an invisible view to balance the plus button
                    Color.clear
                        .frame(width: 44, height: 44) // Match the plus button size
                }// HStack (Top Bar)
                
                .padding(.horizontal)
                .padding(.top, 8)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: UIDevice.current.userInterfaceIdiom == .pad ? 200 : 150), spacing: 20)], spacing: 20) {
                        ForEach(filteredTitles) { title in
                            NavigationLink(destination: TitleView(title: title)) {
                                VStack(spacing: 8) {
                                    if let imageData = title.coverImageData, let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 210 : 150,
                                                   height: UIDevice.current.userInterfaceIdiom == .pad ? 280 : 200)
                                            .cornerRadius(12)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.3))
                                            .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 210 : 150,
                                                   height: UIDevice.current.userInterfaceIdiom == .pad ? 280 : 200)
                                            .cornerRadius(12)
                                            .overlay(Text(title.title.prefix(1))
                                                .font(.largeTitle)
                                                .foregroundColor(.white))
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text(title.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Text(title.author)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 4)
                                }
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                }
                
                
                
            }
            .navigationTitle("Library")
            .navigationBarHidden(true)
            .onAppear {
                loadTitles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .titleAdded)) { _ in
                loadTitles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .titleDeleted)) { _ in
                loadTitles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .titleUpdated)) { _ in
                loadTitles()
            }
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func loadTitles() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            if !fileManager.fileExists(atPath: titlesDirectory.path) {
                try fileManager.createDirectory(at: titlesDirectory, withIntermediateDirectories: true)
                print("Created Titles directory: \(titlesDirectory.path)")
                return
            }
            
            let titleFiles = try fileManager.contentsOfDirectory(at: titlesDirectory, includingPropertiesForKeys: nil)
            var loadedTitles: [Title] = []
            
            for file in titleFiles where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let title = try JSONDecoder().decode(Title.self, from: data)
                    loadedTitles.append(title)
                    print("Loaded title from: \(file.lastPathComponent)")
                } catch {
                    print("Error loading title from \(file.lastPathComponent): \(error)")
                }
            }
            
            titles = loadedTitles
        } catch {
            print("Error loading titles: \(error)")
        }
    }
}
