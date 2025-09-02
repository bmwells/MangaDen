//
//  LibraryView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

    // MARK: Manga File Struct
struct Manga: Identifiable {
    let id = UUID()
    let title: String
    let isDownloaded: Bool
    let isArchived: Bool
}


    // MARK: Library Screen
struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .reading
    @State private var showAddManga: Bool = false
    
    @State private var mangas: [Manga] = [
        Manga(title: "One Piece", isDownloaded: true, isArchived: false),
        Manga(title: "Naruto", isDownloaded: true, isArchived: true),
        Manga(title: "Bleach", isDownloaded: false, isArchived: false),
        Manga(title: "Attack on Titan", isDownloaded: true, isArchived: false),
        Manga(title: "Berserk", isDownloaded: false, isArchived: true)
    ]
    
        // Tabs (Reading, Downloads, Archive)
    enum LibraryTab: String, CaseIterable {
        case reading = "Reading"
        case downloads = "Downloads"
        case archive = "Archive"
    }
    
        // Tab Filters 
    var filteredMangas: [Manga] {
        switch selectedTab {
        case .reading: return mangas.filter { !$0.isArchived }
        case .downloads: return mangas.filter { $0.isDownloaded }
        case .archive: return mangas.filter { $0.isArchived }
        }
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
                    .sheet(isPresented: $showAddManga) { AddMangaView() }
                    
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)]) {
                        ForEach(filteredMangas) { manga in
                            VStack {
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(height: 160)
                                    .cornerRadius(12)
                                    .overlay(Text(manga.title.prefix(1))
                                                .font(.largeTitle)
                                                .foregroundColor(.white))
                                
                                Text(manga.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
            .navigationBarHidden(true)
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

