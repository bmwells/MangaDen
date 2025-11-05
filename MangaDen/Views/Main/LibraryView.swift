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
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var isLoading: Bool = true
    @State private var isLandscape: Bool = false
    @AppStorage("accentColor") private var accentColor: String = "systemBlue"
        
    // Get current accent color
    private var currentAccentColor: Color {
        Color.fromStorage(accentColor)
    }
    
    // Tabs (Reading and Archive)
    enum LibraryTab: String, CaseIterable {
        case reading = "Reading"
        case archive = "Archive"
    }
    
    // Filtered and searched titles
    var filteredTitles: [Title] {
        let filtered: [Title]
        switch selectedTab {
        case .reading: filtered = titles.filter { !$0.isArchived }
        case .archive: filtered = titles.filter { $0.isArchived }
        }
        
        // Apply search filter if searching
        if !searchText.isEmpty {
            let searched = filtered.filter { title in
                title.title.lowercased().contains(searchText.lowercased())
            }
            // Sort searched results alphabetically
            return searched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            // Sort all results alphabetically
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }
    
    // Computed color scheme based on user preference
    private var effectiveColorScheme: ColorScheme {
        return isDarkMode ? .dark : .light
    }
    
    // Computed cover image height based on device and orientation
    private var coverImageHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape ? 263 : 275
        } else {
            return 265
        }
    }
    
    // Computed cover image width based on device and orientation
    private var coverImageWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return isLandscape ? 225 : 225
        } else {
            return 175
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack {
                    // Top Bar with Add, Picker, and Search
                    HStack {
                        // Add Button
                        Button(action: { showAddManga = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(currentAccentColor)
                                .padding(8)
                                .offset(
                                    x: UIDevice.current.userInterfaceIdiom == .pad ? 10 : 0,
                                    y: UIDevice.current.userInterfaceIdiom == .pad ? 0 : -10
                                )
                        }
                        .sheet(isPresented: $showAddManga) { AddTitleView() }
                        
                        Spacer()
                        
                        // Custom Segmented Picker
                        HStack(spacing: 0) {
                            ForEach(LibraryTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    selectedTab = tab
                                }) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(selectedTab == tab ? .white : currentAccentColor)
                                        .frame(width: 100, height: 36)
                                        .background(selectedTab == tab ? currentAccentColor : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if tab != LibraryTab.allCases.last {
                                    Spacer().frame(width: 4)
                                }
                                
                            }
                        }
                        .background(currentAccentColor.opacity(0.1))
                        .cornerRadius(10)
                        .fixedSize()
                        .padding(.horizontal)
                        .offset(y: -10)
                        
                        Spacer()
                        
                        // Search Button
                        Button(action: {
                            withAnimation(.spring()) {
                                isSearching.toggle()
                                if !isSearching {
                                    searchText = ""
                                }
                            }
                        }) {
                            Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                                .font(.system(size: 25, weight: .medium))
                                .foregroundColor(currentAccentColor)
                                .padding(8)
                                .offset(
                                    x: UIDevice.current.userInterfaceIdiom == .pad ? -10 : 0,
                                    y: UIDevice.current.userInterfaceIdiom == .pad ? 0 : -10
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(Color(.systemBackground))
                    
                    // Search Bar (appears when searching)
                    if isSearching {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            TextField("Search your library...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 8)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    ScrollView {
                        if isLoading {
                            VStack {
                                ProgressView("Loading Library...")
                                    .scaleEffect(1.5)
                                    .padding(.horizontal)
                                    .padding(.top, 100)
                            }
                            .frame(maxWidth: .infinity)
                        } else if filteredTitles.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: emptyStateIcon)
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 8) {
                                    Text(emptyStateTitle)
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
                                                    .frame(width: coverImageWidth,
                                                           height: coverImageHeight)
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
                                                        .frame(width: coverImageWidth,
                                                               height: coverImageHeight)
                                                        .cornerRadius(12)
                                                    
                                                    VStack {
                                                        Text(title.title.prefix(1))
                                                            .font(.system(size: 40, weight: .bold))
                                                            .foregroundColor(.accentColor)
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
                                                    .font(.custom("AndaleMono", size: 23))
                                                    .tracking(0.5) // Letter spacing
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            .frame(height: 40) // Fixed height for entire text container
                                            .frame(maxWidth: UIScreen.main.bounds.width * 0.5) // 50% of screen width allowed for title text line
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(16)
                        }
                    }
                    .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 48 : 38)
                    .background(Color(.systemGroupedBackground))
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    // Update orientation based on screen size ratio
                    updateOrientation(for: newSize)
                }
                .onAppear {
                    // Initial orientation check
                    updateOrientation(for: geometry.size)
                }
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
    
    // Empty state properties based on search and selected tab
    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else {
            switch selectedTab {
            case .reading: return "books.vertical.fill"
            case .archive: return "archivebox"
            }
        }
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Results Found"
        } else {
            switch selectedTab {
            case .reading: return "No Titles Found"
            case .archive: return "Archive Empty"
            }
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No titles found matching \"\(searchText)\""
        } else {
            switch selectedTab {
            case .reading:
                return "Your reading list is empty. Add some titles to get started!"
            case .archive:
                return "Your archive is empty. Archive titles you've finished reading."
            }
        }
    }
    
    private func loadTitles() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
                if !fileManager.fileExists(atPath: titlesDirectory.path) {
                    try fileManager.createDirectory(at: titlesDirectory, withIntermediateDirectories: true)
                    DispatchQueue.main.async {
                        self.titles = []
                        self.isLoading = false
                    }
                    return
                }
                
                let titleFiles = try fileManager.contentsOfDirectory(at: titlesDirectory, includingPropertiesForKeys: nil)
                var loadedTitles: [Title] = []
                
                // Process in smaller batches to avoid blocking
                for file in titleFiles where file.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: file)
                        let title = try JSONDecoder().decode(Title.self, from: data)
                        loadedTitles.append(title)
                    } catch {
                        print("Error loading title: \(error)")
                        try? fileManager.removeItem(at: file)
                    }
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.titles = loadedTitles.sorted {
                        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    self.isLoading = false
                }
            } catch {
                print("Error: \(error)")
                DispatchQueue.main.async {
                    self.titles = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func updateOrientation(for size: CGSize) {
        DispatchQueue.main.async {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Use screen size ratio to determine orientation
                self.isLandscape = size.width > size.height
            } else {
                self.isLandscape = false
            }
        }
    }
}

#Preview {
    ContentView()
}
