//
//  SettingsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("defaultReadingDirection") private var defaultReadingDirection: ReadingDirection = .rightToLeft
    @EnvironmentObject private var tabBarManager: TabBarManager
    @State private var showUninstallAllConfirmation = false
    @State private var showNoDownloadsAlert = false
    @State private var totalDownloadSize = "Calculating..."
    @State private var isUninstalling = false
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    // User Preferences
                    Section(header: Text("User Preferences")) {
                        
                        // Dark Mode
                        Toggle("Dark Mode", isOn: $isDarkMode)
                        
                        HStack {
                            Text("Reading Direction")
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: { defaultReadingDirection = .leftToRight }) {
                                    Text("L to R")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(defaultReadingDirection == .leftToRight ? .white : .blue)
                                        .frame(width: 60, height: 32)
                                        .background(defaultReadingDirection == .leftToRight ? Color.blue : Color.clear)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { defaultReadingDirection = .rightToLeft }) {
                                    Text("R to L")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(defaultReadingDirection == .rightToLeft ? .white : .blue)
                                        .frame(width: 60, height: 32)
                                        .background(defaultReadingDirection == .rightToLeft ? Color.blue : Color.clear)
                                        .cornerRadius(6)
                                        
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Manage Storage
                    Section(header: Text("Manage Storage")) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Uninstall ALL Downloads")
                                    .foregroundColor(.primary)
                                
                                // Storage size display
                                HStack {
                                    Text("Total Download Size:")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                    Text(totalDownloadSize)
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            
                            if isUninstalling {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button(action: {
                                    if totalDownloadSize == "0 MB" {
                                        showNoDownloadsAlert = true
                                    } else {
                                        showUninstallAllConfirmation = true
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 25))
                                        .foregroundColor(.red)
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                }
                .listSectionSpacing(.compact)
                
                // Help Button
                HStack {
                    Spacer()
                    Button(action: {
                        showHelp = true
                    }) {
                        Image(systemName: "questionmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                            .padding(20)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(Color(.systemGroupedBackground))
                
                // Version at bottom of page
                VStack {
                    Text("Version 0.85")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(.bottom, 74)
                        .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground))
            }
            .toolbar {
                // Page title
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.largeTitle)
                        .bold()
                }
            }
            .alert("Uninstall ALL Downloads", isPresented: $showUninstallAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uninstall All", role: .destructive) {
                    uninstallAllDownloads()
                }
            } message: {
                Text("Are you sure you want to uninstall ALL downloaded chapters? This will remove all downloaded content from the device and cannot be undone.")
            }
            .alert("No Downloads", isPresented: $showNoDownloadsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No chapters are currently downloaded to device.")
            }
            .sheet(isPresented: $showHelp) {
                SettingsHelpView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            tabBarManager.isTabBarHidden = false
            totalDownloadSize = calculateTotalDownloadSize()
        }
    }
    
    private func uninstallAllDownloads() {
        isUninstalling = true
        
        // Perform the uninstall operation
        DispatchQueue.global(qos: .userInitiated).async {
            uninstallAllChaptersForAllTitles()
            
            DispatchQueue.main.async {
                isUninstalling = false
                totalDownloadSize = "0 MB"
                
                // Clear DownloadManager state
                DownloadManager.shared.clearCompleted()
                DownloadManager.shared.clearQueue()
                DownloadManager.shared.clearFailed()
                
                // Notify the app that titles have been updated
                NotificationCenter.default.post(name: .titleUpdated, object: nil)
            }
        }
    }
    
    private func uninstallAllChaptersForAllTitles() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Error: Could not access documents directory")
                return
            }
            
            // Remove the entire Downloads directory
            let downloadsDirectory = documentsDirectory.appendingPathComponent("Downloads")
            if fileManager.fileExists(atPath: downloadsDirectory.path) {
                try fileManager.removeItem(at: downloadsDirectory)
                print("Removed entire Downloads directory")
            }
            
            // Recreate empty Downloads directory
            try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
            
            // Update all title files to mark all chapters as not downloaded
            updateAllTitleFiles()
            
            print("Successfully uninstalled all downloads for all titles")
            
        } catch {
            print("Error uninstalling all downloads: \(error)")
        }
    }
    
    private func updateAllTitleFiles() {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
            
            // Check if titles directory exists
            if fileManager.fileExists(atPath: titlesDirectory.path) {
                let titleFiles = try fileManager.contentsOfDirectory(at: titlesDirectory, includingPropertiesForKeys: nil)
                
                for titleFile in titleFiles where titleFile.pathExtension == "json" {
                    do {
                        let data = try Data(contentsOf: titleFile)
                        var title = try JSONDecoder().decode(Title.self, from: data)
                        
                        // Update all chapters to not downloaded
                        for index in title.chapters.indices {
                            title.chapters[index].isDownloaded = false
                            title.chapters[index].fileSize = 0
                        }
                        
                        // Save the updated title
                        let updatedData = try JSONEncoder().encode(title)
                        try updatedData.write(to: titleFile)
                        
                        print("Updated title: \(title.title)")
                        
                    } catch {
                        print("Error updating title file \(titleFile.lastPathComponent): \(error)")
                    }
                }
            }
        } catch {
            print("Error accessing title files: \(error)")
        }
    }
    
    private func calculateTotalDownloadSize() -> String {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return "0 MB"
            }
            
            let downloadsDirectory = documentsDirectory.appendingPathComponent("Downloads")
            
            // Check if downloads directory exists
            if fileManager.fileExists(atPath: downloadsDirectory.path) {
                let chapterDirectories = try fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                
                // If directory exists but is empty, return "0 MB"
                if chapterDirectories.isEmpty {
                    return "0 MB"
                }
                
                var totalSize: Int64 = 0
                
                for chapterDir in chapterDirectories {
                    // Check if it's a directory (each chapter is in its own folder)
                    let resourceValues = try chapterDir.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues.isDirectory == true {
                        // Calculate size of all files in this chapter directory
                        let chapterFiles = try fileManager.contentsOfDirectory(at: chapterDir, includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                        
                        for file in chapterFiles {
                            let fileResourceValues = try file.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                            totalSize += Int64(fileResourceValues.fileSize ?? fileResourceValues.totalFileAllocatedSize ?? 0)
                        }
                    }
                }
                
                // If total size is 0, return "0 MB"
                if totalSize == 0 {
                    return "0 MB"
                }
                
                // Format the size
                return formatFileSize(totalSize)
            }
        } catch {
            print("Error calculating download size: \(error)")
        }
        
        return "0 MB"
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: Settings Help View
struct SettingsHelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Settings Guide
                    Text("Settings Guide")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 20)
                    
                    Text("**User Preferences**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("**Dark Mode:** Toggle between light and dark app appearance.")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text("**Reading Direction**: Choose between Left to Right (L to R) or Right to Left (L to R) reading direction.")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    
                    Text("**Manage Storage**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("**Uninstall All Downloads**: Remove all downloaded chapters from your device to free up storage space.")
                    
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 30)
                    
                    
                    
                    // Title Guide
                    Text("Title Guide")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 20)
                    
                    Text("**Refresh Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Checks for new chapters.")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    

                    Text("**Edit Title Info**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Modify the title, author, status, or cover image.")
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    

                    Text("**Download Chapters**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Download multiple chapters for offline reading.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    

                    Text("**Manage Chapters**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Uninstall downloaded chapters or hide chapters from the list.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    

                    Text("**Archive Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Moves the title from the Reading section to the Archive section.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    Text("**Delete Title**")
                        .font(.title3)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Permanently removes the title from your library.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    
                    // Tip
                    Text("Tip:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                    
                }
                .padding()
            }
            .padding(15)

        }
    }
}


#Preview {
    SettingsHelpView()
}
