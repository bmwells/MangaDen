//
//  LibraryView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

// MARK: - Library Screen
struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .reading
    @State private var showAddManga: Bool = false
    @EnvironmentObject private var tabBarManager: TabBarManager
    @State private var titles: [Title] = []
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) private var systemColorScheme
    
    // Tabs (Reading and Archive)
    enum LibraryTab: String, CaseIterable {
        case reading = "Reading"
        case archive = "Archive"
    }
    
    // Tab Filters
    var filteredTitles: [Title] {
        let filtered: [Title]
        switch selectedTab {
        case .reading: filtered = titles.filter { !$0.isArchived }
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
                    .scaleEffect(x: 1.3, y: 1.3)
                    .offset (x:-25, y: -5)
                    
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
                                            // Title Text below Image
                                            Text(title.title)
                                                .font(.custom("AndaleMono", size: 20))
                                                .tracking(0.6) // Letter spacing
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .fixedSize(horizontal: false, vertical: true)
                                                .padding(.horizontal, 4) // Horizontal padding for better text wrapping
                                                .minimumScaleFactor(0.8)

                                            
                                            // Download info for downloaded titles
                                            if title.isDownloaded && !title.downloadedChapters.isEmpty {
                                                HStack(spacing: 4) {
                                                    Text("\(title.downloadedChapters.count) Chp\(title.downloadedChapters.count > 1 ? "s" : "")")
                                                        .font(.caption2)
                                                        .fontWeight(.medium)
                                                    
                                                    Text("[\(title.formattedDownloadSize)]")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .frame(height: 40) // Fixed height for entire text container
                                        .frame(maxWidth: .infinity) // Ensure consistent width
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(.bottom, 45)
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
            .onReceive(NotificationCenter.default.publisher(for: .downloadCompleted)) { _ in
                loadTitles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .chapterReadStatusChanged)) { _ in
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

#Preview {
    ContentView()
}
