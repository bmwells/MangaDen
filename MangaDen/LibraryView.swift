//
//  LibraryView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import Foundation
import SwiftUI

struct Manga: Identifiable {
    let id = UUID()
    let title: String
    let isDownloaded: Bool
    let isArchived: Bool
}

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
    
    enum LibraryTab: String, CaseIterable {
        case reading = "Reading"
        case downloads = "Downloads"
        case archive = "Archive"
    }
    
    var filteredMangas: [Manga] {
        switch selectedTab {
        case .reading: return mangas.filter { !$0.isArchived }
        case .downloads: return mangas.filter { $0.isDownloaded }
        case .archive: return mangas.filter { $0.isArchived }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: { showAddManga = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .padding(8)
                    }
                    .sheet(isPresented: $showAddManga) { AddMangaView() }
                    
                    Spacer()
                    
                    Picker("", selection: $selectedTab) {
                        ForEach(LibraryTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 250)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .padding(8)
                    }
                }
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

