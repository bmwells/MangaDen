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
    var title: String
    var author: String
    let status: String
    var coverImageData: Data?
    let chapters: [Chapter]
    let metadata: [String: Any]
    var isDownloaded: Bool
    var isArchived: Bool
    var sourceURL: String?
    
    // Coding keys to handle the metadata dictionary
    enum CodingKeys: String, CodingKey {
        case id, title, author, status, coverImageData, chapters, isDownloaded, isArchived, metadata, sourceURL
    }
    
    init(id: UUID = UUID(), title: String, author: String, status: String,
         coverImageData: Data?, chapters: [Chapter], metadata: [String: Any],
         isDownloaded: Bool = false, isArchived: Bool = false, sourceURL: String? = nil) { // ADD sourceURL PARAMETER
        self.id = id
        self.title = title
        self.author = author
        self.status = status
        self.coverImageData = coverImageData
        self.chapters = chapters
        self.metadata = metadata
        self.isDownloaded = isDownloaded
        self.isArchived = isArchived
        self.sourceURL = sourceURL
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
        try container.encode(sourceURL, forKey: .sourceURL) // ENCODE sourceURL
        
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
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL) // DECODE sourceURL
        
        // Decode metadata from JSON data
        let metadataData = try container.decode(Data.self, forKey: .metadata)
        metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] ?? [:]
    }
}

// MARK: - Library Screen
struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .reading
    @State private var showAddManga: Bool = false
    @EnvironmentObject private var tabBarManager: TabBarManager
    @State private var titles: [Title] = []
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) private var systemColorScheme
    
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
    
    // Computed color scheme based on user preference
    private var effectiveColorScheme: ColorScheme {
        return isDarkMode ? .dark : .light
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: { showAddManga = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .offset(x: 0, y: -15)
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
                    .scaleEffect(x: 0.9, y: 1.0)
                    .offset(y: -5)
                    
                    Spacer()
                    
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(.systemBackground))
                
                ScrollView {
                    if filteredTitles.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("No Titles Found")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(emptyStateMessage)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
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
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                                )
                                        } else {
                                            ZStack {
                                                Rectangle()
                                                    .fill(Color.accentColor.opacity(0.3))
                                                    .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 210 : 150,
                                                           height: UIDevice.current.userInterfaceIdiom == .pad ? 280 : 200)
                                                    .cornerRadius(12)
                                                
                                                VStack {
                                                    Text(title.title.prefix(1))
                                                        .font(.system(size: 40, weight: .bold))
                                                        .foregroundColor(.accentColor)
                                                    Text("No Cover")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                        }
                                        
                                        VStack(spacing: 4) {
                                            Text(title.title)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .multilineTextAlignment(.center)
                                            
                                            Text(title.author)
                                                .font(.caption2)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .preferredColorScheme(effectiveColorScheme)
            .onAppear {
                tabBarManager.isTabBarHidden = false
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // Empty state message based on selected tab
    private var emptyStateMessage: String {
        switch selectedTab {
        case .reading:
            return "Your reading list is empty. Add some titles to get started!"
        case .downloads:
            return "No downloaded titles yet. Download titles to read them offline."
        case .archive:
            return "Your archive is empty. Archive titles you've finished reading."
        }
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
                    if let sourceURL = title.sourceURL {
                        print("Title '\(title.title)' has source URL: \(sourceURL)")
                    }
                } catch {
                    print("Error loading title from \(file.lastPathComponent): \(error)")
                }
            }
            
            titles = loadedTitles
            print("Loaded \(titles.count) titles from library")
        } catch {
            print("Error loading titles: \(error)")
        }
    }
}

