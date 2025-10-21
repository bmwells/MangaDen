//
//  SettingsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("defaultReadingDirection") private var defaultReadingDirection: ReadingDirection = .rightToLeft
    @AppStorage("defaultBrowserWebsite") private var defaultBrowserWebsite: String = "https://google.com"
    @StateObject private var autoRefreshManager = AutoRefreshManager.shared
    @EnvironmentObject private var tabBarManager: TabBarManager
    @State private var showUninstallAllConfirmation = false
    @State private var showNoDownloadsAlert = false
    @State private var totalDownloadSize = "Calculating..."
    @State private var isUninstalling = false
    @State private var showHelp = false
    @State private var browserWebsiteInput: String = ""
    @State private var showInvalidURLError = false
    
    private var currentRefreshPeriod: RefreshPeriod {
        autoRefreshManager.getRefreshPeriod()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    // User Preferences
                    Section(header: Text("User Preferences")) {
                        
                        // Dark Mode
                        Toggle("Dark Mode", isOn: $isDarkMode)
                        
                        // Reading Direction
                        HStack {
                            Text("Default Reading Direction")
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
                        
                        // Default Title Refresh Period
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Title Refresh Period")
                                .foregroundColor(.primary)
                            
                            Picker("Refresh Period", selection: Binding(
                                get: { currentRefreshPeriod },
                                set: { autoRefreshManager.setRefreshPeriod($0) }
                            )) {
                                ForEach(RefreshPeriod.allCases, id: \.self) { period in
                                    Text(period.displayName).tag(period)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onAppear {
                                // Customize segmented control appearance
                                UISegmentedControl.appearance().selectedSegmentTintColor = .systemBlue
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.systemBlue], for: .normal)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // NEW: Default Browser Website
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Browser Website")
                                .foregroundColor(.primary)
                            
                            HStack {
                                TextField("Enter website URL", text: $browserWebsiteInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onAppear {
                                        // Initialize the input field with the stored value
                                        browserWebsiteInput = formatWebsiteForDisplay(defaultBrowserWebsite)
                                    }
                                
                                Button("Save") {
                                    saveBrowserWebsite()
                                }
                                .buttonStyle(.bordered)
                                .disabled(browserWebsiteInput.isEmpty)
                            }
                            
                            if showInvalidURLError {
                                Text("Please enter a valid website (e.g., google.com or https://website.com)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
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
                    Text("Version 1.0")
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
            }
            
            // Recreate empty Downloads directory
            try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
            
            // Update all title files to mark all chapters as not downloaded
            updateAllTitleFiles()
                        
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
    
    // MARK: - Browser Website Methods
    
    private func formatWebsiteForDisplay(_ website: String) -> String {
        // Remove https:// and trailing slash for display in text field
        var displayText = website
        if displayText.hasPrefix("https://") {
            displayText = String(displayText.dropFirst(8))
        }
        if displayText.hasSuffix("/") {
            displayText = String(displayText.dropLast())
        }
        return displayText
    }
    
    private func formatWebsiteForStorage(_ input: String) -> String {
        var formatted = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any existing http:// or https://
        if formatted.hasPrefix("http://") {
            formatted = String(formatted.dropFirst(7))
        } else if formatted.hasPrefix("https://") {
            formatted = String(formatted.dropFirst(8))
        }
        
        // Remove trailing slash
        if formatted.hasSuffix("/") {
            formatted = String(formatted.dropLast())
        }
        
        // Add https:// and ensure it's a valid URL format
        return "https://\(formatted)"
    }
    
    private func saveBrowserWebsite() {
        let input = browserWebsiteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation - should not be empty and should look like a domain
        guard !input.isEmpty else {
            showInvalidURLError = true
            return
        }
        
        // Check if it looks like a valid domain (contains a dot or is localhost)
        let isValidDomain = input.contains(".") || input == "localhost" || input.hasPrefix("localhost:")
        
        guard isValidDomain else {
            showInvalidURLError = true
            return
        }
        
        showInvalidURLError = false
        
        // Format and save the website
        let formattedWebsite = formatWebsiteForStorage(input)
        defaultBrowserWebsite = formattedWebsite
        
        // Show success feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Reset the text field to display format
        browserWebsiteInput = formatWebsiteForDisplay(formattedWebsite)
    }
}

// MARK: Settings Help View
struct SettingsHelpView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCopiedAlert = false
    
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
                    
                    Text("**Dark Mode**").font(.system(size: 20)).italic() + Text(": Toggle between light and dark app appearance.")
                        .font(.system(size: 20))

                    Text("**Reading Direction**").font(.system(size: 20)).italic() + Text(": Choose between Left to Right (L to R) or Right to Left (L to R) reading direction.")
                        .font(.system(size: 20))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    Text("**Manage Storage**")
                        .font(.title2)
                        .underline()
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("**Uninstall All Downloads**").font(.system(size: 20)).italic() + Text(": Remove all downloaded chapters from your device to free up storage space.")
                        .font(.system(size: 20))
                    
                    //Divider
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    
                    // Tip
                    Text("Tips:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                        .font(.system(size: 18))
                        .tracking(1.0)
                    Text("• For any questions or concerns feel free to email our team by copying the email below")
                        .font(.system(size: 18))
                        .tracking(1.0)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = "brwe47@gmail.com"
                            showCopiedAlert = true
                        }) {
                            Text("Copy Team Email Here")
                                .foregroundColor(.blue)
                                .underline()
                                .font(.title)
                                .padding(.top, 4)
                        }
                        Spacer()
                    }
                    .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("Team email has been copied to your clipboard.")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, horizontalSizeClass == .regular ? 20 : 15)
            .frame(maxWidth: horizontalSizeClass == .regular ? 800 : .infinity)
        }
    }
}


#Preview {
    ContentView()
}
