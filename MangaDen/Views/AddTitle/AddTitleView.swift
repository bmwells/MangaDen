//
//  AddTitleView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI
import WebKit

struct AddTitleView: View {
    @State private var urlText: String = ""
    @State private var showBrowser = false
    @State private var showHelp = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Title to Library")
                    .font(.system(size: 40))
                    .padding(.top, 30)
                
                Spacer()

                ZStack {
                    // Paste Manga field
                    TextField("Paste Manga URL", text: $urlText)
                        .frame(maxWidth: .infinity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.trailing, 40)
                        .disabled(isLoading)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    HStack {
                        Spacer()
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                urlText = clipboard
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Add from URL paste
                if isLoading {
                    ProgressView("Processing URL...")
                        .padding()
                } else {
                    Button("Add") {
                        processURL()
                    }
                    .font(.title)
                    .tracking(2.0)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 47)
                    .background(urlText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .disabled(urlText.isEmpty)
                }
                
                Spacer()

                // OR divider
                Text("OR")
                    .font(.title)
                    .foregroundColor(.primary)
                    .tracking(3.0)
                
                Spacer()

                // In App Browser Button
                Button(action: {
                    showBrowser = true
                }) {
                    Label("Open In-App Browser", systemImage: "safari")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(isLoading)
                
                Spacer()

                // Help Button
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
                .disabled(isLoading)

                Spacer()
            }
        }
        // Browser sheet
        .sheet(isPresented: $showBrowser) {
            BrowserView()
        }
        // Help sheet
        .sheet(isPresented: $showHelp) {
            AddTitleHelpView()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - URL Processing Logic
    
    private func processURL() {
        guard !urlText.isEmpty else {
            showAlert(title: "Error", message: "Please enter a URL")
            return
        }
        
        guard let url = URL(string: urlText) else {
            showAlert(title: "Invalid URL", message: "Please enter a valid URL")
            return
        }
        
        isLoading = true
        
        // Process the URL in the background
        Task {
            await processTitleFromURL(url)
        }
    }
    
    @MainActor
    private func processTitleFromURL(_ url: URL) async {
        do {
            print("Starting title extraction from URL: \(url)")
            
            // Use WebViewManager to handle the web view
            let webViewManager = WebViewManager()
            
            // Set up a navigation delegate to wait for page load
            let navigationDelegate = TitleExtractionNavigationDelegate()
            webViewManager.navigationDelegate = navigationDelegate
            
            // Load the URL and wait for completion
            webViewManager.loadChapter(url: url)
            
            // Wait for page to load
            try await navigationDelegate.waitForLoad()
            
            guard let webView = webViewManager.webView else {
                throw NSError(domain: "TitleExtraction", code: 1, userInfo: [NSLocalizedDescriptionKey: "WebView failed to load"])
            }
            
            print("Page loaded, extracting metadata and chapters...")
            
            // Extract metadata using MetadataExtractionManager
            let metadata = await withCheckedContinuation { continuation in
                MetadataExtractionManager.findMangaMetadata(in: webView) { metadata in
                    continuation.resume(returning: metadata ?? [:])
                }
            }
            
            print("Metadata extracted: \(metadata)")
            
            // Extract chapters using ChapterExtractionManager
            let chapters = await withCheckedContinuation { continuation in
                ChapterExtractionManager.findChapterLinks(in: webView) { chapters in
                    continuation.resume(returning: chapters ?? [:])
                }
            }
            
            print("Chapters extracted: \(chapters.count) chapters found")
            
            // Extract cover image using the title_image from metadata
            let coverImageData = await downloadCoverImage(from: metadata)
            
            // Create Title object
            let title = createTitle(from: metadata, chapters: chapters, url: url.absoluteString, coverImageData: coverImageData)
            
            // Save to library
            await saveTitleToLibrary(title)
            
            // Show success message
            showAlert(title: "Success", message: "Title '\(title.title)' added to library with \(title.chapters.count) chapters")
            
        } catch {
            print("Error processing URL: \(error)")
            showAlert(title: "Error", message: "Failed to process URL: \(error.localizedDescription)")
        }
        
        isLoading = false
    }

    // MARK: - Cover Image Extraction

    private func downloadCoverImage(from metadata: [String: Any]) async -> Data? {
        return await withCheckedContinuation { continuation in
            // Get cover image URL from metadata (this is already extracted in your MetadataExtractionJavaScript)
            if let coverImageUrlString = metadata["title_image"] as? String,
               let coverImageUrl = URL(string: coverImageUrlString) {
                
                print("Downloading cover image from: \(coverImageUrlString)")
                
                let task = URLSession.shared.dataTask(with: coverImageUrl) { data, response, error in
                    if let error = error {
                        print("Error downloading cover image: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let data = data, !data.isEmpty else {
                        print("No data received for cover image")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    // Verify it's actually image data
                    if let image = UIImage(data: data) {
                        print("Successfully downloaded cover image: \(image.size)")
                        continuation.resume(returning: data)
                    } else {
                        print("Downloaded data is not a valid image")
                        continuation.resume(returning: nil)
                    }
                }
                task.resume()
            } else {
                print("No cover image URL found in metadata")
                continuation.resume(returning: nil)
            }
        }
    }

    private func createTitle(from metadata: [String: Any], chapters: [String: [String: String]], url: String, coverImageData: Data?) -> Title {
        let titleName = metadata["title"] as? String ?? "Unknown Title"
        let author = metadata["author"] as? String ?? "Unknown Author"
        let status = metadata["status"] as? String ?? "releasing"
        
        // Convert chapter dictionary to Chapter objects
        let chapterObjects = chapters.map { chapterNumber, chapterData in
            Chapter(
                chapterNumber: Double(chapterNumber) ?? 0.0,
                url: chapterData["url"] ?? "",
                title: chapterData["title"] ?? "Chapter \(chapterNumber)",
                uploadDate: chapterData["upload_date"],
                isDownloaded: false,
                isRead: false
            )
        }.sorted { $0.chapterNumber > $1.chapterNumber } // Sort descending (newest first)
        
        return Title(
            id: UUID(),
            title: titleName,
            author: author,
            status: status,
            coverImageData: coverImageData, // Use the downloaded cover image data
            chapters: chapterObjects,
            metadata: metadata,
            isDownloaded: false,
            isArchived: false,
            sourceURL: url
        )
    }
    
    private func saveTitleToLibrary(_ title: Title) async {
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
        
        // Create Titles directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: titlesDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating Titles directory: \(error)")
            return
        }
        
        // Save title as JSON
        let titleFile = titlesDirectory.appendingPathComponent("\(title.id.uuidString).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let titleData = try encoder.encode(title)
            try titleData.write(to: titleFile)
            print("Title saved to: \(titleFile.path)")
            print("Title: \(title.title)")
            print("Author: \(title.author)")
            print("Chapters: \(title.chapters.count)")
            print("Cover image: \(title.coverImageData != nil ? "Yes" : "No")")
            
            // Post notification to refresh library - USE THE CORRECT NAME
            NotificationCenter.default.post(name: .titleAdded, object: nil)
            print("Posted titleAdded notification")
            
        } catch {
            print("Error saving title: \(error)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Navigation Delegate for Title Extraction

private class TitleExtractionNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    
    func waitForLoad() async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let titleAddedToLibrary = Notification.Name("titleAddedToLibrary")
}

// MARK: - Help View
struct AddTitleHelpView: View {
    @State private var showCopiedAlert = false
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Add Titles")
                        .underline()
                        .font(.system(size: 40))
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    HStack {
                        Spacer()
                        VStack(alignment: .center, spacing: 4) {
                            Text("Paste a valid title page's URL into text box")
                                .font(.system(size: 17))
                            Text("OR")
                                .font(.title2)
                                .bold()
                            Text("Use the In-App Browser (**Recommended**)")
                                .padding(.bottom, 10)
                                .font(.system(size: 17))
                        }
                        Spacer()
                    }
                    
                    Text("In-App Browser Guide")
                        .font(.title)
                        .bold()
                        .underline()
                        .padding(.bottom, 5)

                    Text("• The **'Add Title'** button will turn ").font(.system(size: 18)) + Text("GREEN").foregroundColor(.green).font(.system(size: 18)) + Text(" when there is a potential title that can be added to the library.")
                        .font(.system(size: 18))

                    HStack(alignment: .top) {
                        Text("• Use the title view button to check for validity of current page's title.")
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("• Use the refresh button to recheck the page for title info.")
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    HStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 125) {
                        VStack {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                        }
                        
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, -5)
                    
                    Text("Supported Sites")
                        .font(.title)
                        .bold()
                        .underline()
                        .padding(.bottom, 20)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        WebsiteButton(url: "https://mangafire.to/home/", name: "MangaFire")
                        WebsiteButton(url: "https://readcomiconline.li/", name: "ReadComicOnline")
                        
                        //WebsiteButton(url: "https://batcave.biz/", name: "BatCave")
                        //WebsiteButton(url: "https://comicbookplus.com/", name: "ComicBookPlus")
                        //WebsiteButton(url: "https://mangaberri.com/, name: "MangaBerri")
                        //WebsiteButton(url: "https://weebcentral.com/, name: "WeebCentral")
                        
                        
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                    Text("Tips:")
                        .padding(-4)
                        .font(.title2)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• If you don't see a title you'd like to read on one of the supported sites, try Googling 'read [TITLE] online' as there are typically sites that exclusively host that title and are usually compatible with the app.")
                        .font(.system(size: 18))
                        .tracking(0.8)
                    Text("• If you would like a site to become compatible, request it by copying the email below and sending a message to our team.")
                        .font(.system(size: 18))
                        .tracking(0.8)
                    
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
            }
            .padding(10)
        }
    }
    
    struct WebsiteButton: View {
        let url: String
        let name: String
        @State private var showCopiedAlert = false
        
        var body: some View {
            Button(action: {
                UIPasteboard.general.string = url
                showCopiedAlert = true
            }) {
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(url) has been copied to your clipboard.")
            }
        }
    }
}

#Preview {
    AddTitleHelpView()
}
