//
//  ContentView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI
import SafariServices

    // Main Screen
struct ContentView: View {
    var body: some View {
        TabView {
            // Library Tab
            LibraryView()
                .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            
            // Downloads Tab
                        DownloadsView()
                            .tabItem {
                            Label("Downloads", systemImage: "arrow.down.circle")
                        }
            
            // Settings Tab 
                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                    }
                }
            }


struct Manga: Identifiable {
    let id = UUID()
    let title: String
    let isDownloaded: Bool
    let isArchived: Bool
}

// MARK: - LibraryView
struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .reading
    @State private var showAddManga: Bool = false
    
    // Sample manga data
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
        case .reading:
            return mangas.filter { !$0.isArchived }
        case .downloads:
            return mangas.filter { $0.isDownloaded }
        case .archive:
            return mangas.filter { $0.isArchived }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // MARK: Top Bar
                HStack {
                    // Plus button
                    Button(action: {
                        showAddManga = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .padding(8)
                    }
                    .sheet(isPresented: $showAddManga) {
                        AddMangaView()
                    }
                    
                    Spacer()
                    
                    // Tabs (Segmented Picker)
                    Picker("", selection: $selectedTab) {
                        ForEach(LibraryTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 250)
                    
                    Spacer()
                    
                    // Refresh button
                    Button(action: {
                        // Refresh action
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // MARK: Manga Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)]) {
                        ForEach(filteredMangas) { manga in
                            VStack {
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(height: 160)
                                    .cornerRadius(12)
                                    .overlay(
                                        Text(manga.title.prefix(1)) // placeholder image
                                            .font(.largeTitle)
                                            .foregroundColor(.white)
                                    )
                                
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
        
        .navigationViewStyle(StackNavigationViewStyle())

    }
}

// MARK: - AddMangaView
struct AddMangaView: View {
    @Environment(\.dismiss) var dismiss
    @State private var urlText: String = ""
    @State private var showBrowser: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Paste Manga URL", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    // Open in app browser
                    showBrowser = true
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open in App Browser")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Add Manga")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showBrowser) {
                if let url = URL(string: urlText), !urlText.isEmpty {
                    SafariView(url: url)
                } else {
                    Text("Invalid URL")
                }
            }
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - SafariView for in-app browser
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}



struct DownloadsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Downloading Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("Downloading")
                        .font(.headline)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            // Pause action here
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Queue Box
                VStack(alignment: .leading, spacing: 10) {
                    Text("Queue")
                        .font(.headline)
                    
                    Text("No items in queue")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Downloads")
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Dark Mode", isOn: .constant(false))
                    Toggle("Notifications", isOn: .constant(true))
                }
                
                Section(header: Text("Account")) {
                    NavigationLink("Profile", destination: Text("Profile Settings"))
                    NavigationLink("Privacy", destination: Text("Privacy Settings"))
                }
                
                Section {
                    Button(role: .destructive) {
                        // Action for sign out
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


#Preview {
    ContentView()
}
