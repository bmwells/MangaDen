//
//  BrowserView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
@preconcurrency import WebKit

struct BrowserView: View {
    
    @State private var showJSONViewer = false
    @State private var bothJSONsExist = false
    @State private var isAddingTitle = false
    @State private var addTitleError: String?
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    
    @State private var urlString: String = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var lastLoadTime = Date.distantPast
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var containsChapter = false
    @State private var chapterRange: String = "0-0-0"
    @State private var mangaMetadata: [String: Any]? = nil
    @FocusState private var isURLFieldFocused: Bool
    @State private var isSwitchingToMobile = false
    @State private var jsonCheckTimer: Timer?

    private let webView = WKWebView()
    private let coordinator: WebViewCoordinator

    init() {
        let coord = WebViewCoordinator()
        self.coordinator = coord
        webView.navigationDelegate = coord
        coord.attachObservers(to: webView)
        
        // Set mobile user agent by default for display
        WebViewUserAgentManager.setMobileUserAgent(for: webView)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Navigation Bar
            HStack {
                // Back Button
                Button(action: { webView.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(canGoBack ? .blue : .gray)
                }
                .disabled(!canGoBack)

                // Refresh Button
                Button(action: { webView.reload() }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }

                // Forward Button
                Button(action: { webView.goForward() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(canGoForward ? .blue : .gray)
                }
                .disabled(!canGoForward)

                // URL Bar
                TextField("Enter URL or search terms", text: $urlString, onCommit: {
                    loadURL()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.webSearch)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isURLFieldFocused)
                .submitLabel(.go)
                .onSubmit {
                        loadURL()
                    }

                // Go Button
                Button(action: {
                    loadURL()
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))

            // MARK: Controls Row
            HStack {
                Spacer()
                // Add Title Button (Center)
                Button(action: addTitleToLibrary) {
                    if isAddingTitle {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Add Title")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(bothJSONsExist ? Color.green : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(!bothJSONsExist || isAddingTitle)
                
                Spacer()
                
                // Refresh, Chapter Range and JSON Viewer (Right)
                HStack(spacing: 12) {
                    // Refresh Button
                    Button(action: {
                        // Refresh JSON data for current page
                        findChapters()
                        findMetadata()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                    
                    // Chapter Range
                    Text(chapterRange)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(3)
                    
                    // JSON Viewer Button
                    Button(action: {
                        showJSONViewer.toggle()
                    }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray5))

            // Error message
            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
            }

            Divider()

            // MARK: WebView
            WebViewWrapper(webView: webView)
                .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear {
            // Clear both JSON files when browser is opened
            clearJSONCache()
            
            // Load a default page if no URL is specified
            if urlString.isEmpty {
                urlString = "https://google.com"
                loadURL()
            }
            // Load existing chapter data if available
            loadChapterRange()
            // Load existing metadata if available
            loadMangaMetadata()
            checkJSONsExist()
            
            // Set up timer to periodically check for JSON files
            jsonCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                checkJSONsExist()
            }
        }
        .onDisappear {
            // Invalidate the timer when the view disappears
            jsonCheckTimer?.invalidate()
            jsonCheckTimer = nil
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateWebViewNav)) { notification in
            if let info = notification.userInfo as? [String: Any] {
                canGoBack = info["canGoBack"] as? Bool ?? false
                canGoForward = info["canGoForward"] as? Bool ?? false
                
                if let currentURL = info["currentURL"] as? URL, !isURLFieldFocused {
                    urlString = currentURL.absoluteString
                }
                
                isLoading = info["isLoading"] as? Bool ?? false
                
                // Only show errors that aren't the cancelled error (-999)
                if let error = info["error"] as? String {
                    // Check if it's the cancelled error (we don't want to show this to users)
                    if !error.contains("cancelled") && !error.contains("-999") {
                        errorMessage = error
                        showError = true
                    } else {
                        showError = false
                    }
                } else {
                    showError = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didFindChapterWord)) { notification in
            if let containsChapter = notification.userInfo?["containsChapter"] as? Bool {
                self.containsChapter = containsChapter
                // If chapter is found, automatically search for chapter links and metadata
                if containsChapter {
                    findChapters()
                    findMetadata()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateChapterRange)) { notification in
            if let range = notification.userInfo?["chapterRange"] as? String {
                self.chapterRange = range
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .titleAddedSuccess)) { notification in
            if let title = notification.userInfo?["title"] as? String{
                successMessage = "\(title) has been successfully added to your library!"
                showSuccessAlert = true
            }
        }
        .sheet(isPresented: $showJSONViewer) {
            JSONViewerView()
        }
        .alert("Error Adding Title", isPresented: .constant(addTitleError != nil), actions: {
            Button("OK") { addTitleError = nil }
        }, message: {
            if let error = addTitleError {
                Text(error)
            }
        })
        .alert("Success", isPresented: $showSuccessAlert, actions: {
            Button("OK") { showSuccessAlert = false }
        }, message: {
            Text(successMessage)
        })
    }

    private func loadURL() {
        // Prevent rapid successive loads (debounce)
        let now = Date()
        if now.timeIntervalSince(lastLoadTime) < 0.5 { // 500ms debounce
            return
        }
        lastLoadTime = now
        
        showError = false
        containsChapter = false
        chapterRange = "0-0-0"
        mangaMetadata = nil
        isSwitchingToMobile = false // RESET THE FLAG
        
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty input
        if input.isEmpty {
            errorMessage = "Please enter a URL or search terms"
            showError = true
            return
        }
        
        // Set desktop user agent BEFORE loading the URL for scraping
        WebViewUserAgentManager.setDesktopUserAgent(for: webView)
        
        // Check if it's a valid URL
        if let url = URL(string: input), UIApplication.shared.canOpenURL(url) {
            webView.load(URLRequest(url: url))
        } else if let url = URL(string: "https://" + input), UIApplication.shared.canOpenURL(url) {
            urlString = "https://" + input
            webView.load(URLRequest(url: url))
        } else {
            let searchQuery = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            if let searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)") {
                urlString = searchURL.absoluteString
                webView.load(URLRequest(url: searchURL))
            } else {
                errorMessage = "Invalid URL or search terms"
                showError = true
            }
        }
        
        isURLFieldFocused = false
    }
    
    private func findChapters() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ChapterExtractionManager.findChapterLinks(in: webView) { chapterDict in
                if let chapters = chapterDict {
                    let urlDict = ChapterExtractionManager.extractURLs(from: chapters)
                    self.updateChapterRange(from: urlDict)
                }
            }
        }
    }
    
    private func findMetadata() {
        // Wait a moment for the desktop transformation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MetadataExtractionManager.findMangaMetadata(in: self.webView) { metadata in
                if let metadata = metadata {
                    self.mangaMetadata = metadata
                }
                
                // Switch back to mobile user agent but DON'T reload
                DispatchQueue.main.async {
                    // Set flag to prevent infinite loop
                    self.isSwitchingToMobile = true
                    
                    WebViewUserAgentManager.setMobileUserAgent(for: self.webView)
                    
                    // Use JavaScript to apply mobile styling instead of reloading
                    let mobileViewportJS = """
                    // Set mobile viewport
                    var viewportMeta = document.querySelector('meta[name="viewport"]');
                    if (!viewportMeta) {
                        viewportMeta = document.createElement('meta');
                        viewportMeta.name = 'viewport';
                        document.head.appendChild(viewportMeta);
                    }
                    viewportMeta.content = 'width=device-width, initial-scale=1.0';
                    
                    // Force mobile-friendly styling
                    document.documentElement.style.maxWidth = '100%';
                    document.body.style.maxWidth = '100%';
                    document.body.style.overflowX = 'hidden';
                    """
                    
                    self.webView.evaluateJavaScript(mobileViewportJS) { _, error in
                        if let error = error {
                            print("Error applying mobile styling: \(error)")
                        }
                        // Reset flag
                        self.isSwitchingToMobile = false
                    }
                }
            }
        }
    }
    
    private func updateChapterRange(from chapters: [String: String]) {
        // Extract and sort chapter numbers
        let chapterNumbers = chapters.keys.compactMap { Double($0) }.sorted()
        
        if chapterNumbers.isEmpty {
            chapterRange = "0-0-0"
        } else if chapterNumbers.count == 1 {
            let onlyChapter = chapterNumbers[0]
            let formatted = onlyChapter == floor(onlyChapter) ? String(format: "%.0f", onlyChapter) : String(onlyChapter)
            chapterRange = "\(formatted)-\(formatted)-\(formatted)"
        } else {
            let firstChapter = chapterNumbers[0]
            let lastChapter = chapterNumbers[chapterNumbers.count - 1]
            
            // Calculate middle chapter (round to nearest if even count)
            let middleIndex = chapterNumbers.count / 2
            let middleChapter = chapterNumbers[middleIndex]
            
            // Format numbers appropriately (remove .0 if integer)
            let firstFormatted = firstChapter == floor(firstChapter) ? String(format: "%.0f", firstChapter) : String(firstChapter)
            let middleFormatted = middleChapter == floor(middleChapter) ? String(format: "%.0f", middleChapter) : String(middleChapter)
            let lastFormatted = lastChapter == floor(lastChapter) ? String(format: "%.0f", lastChapter) : String(lastChapter)
            
            chapterRange = "\(firstFormatted)-\(middleFormatted)-\(lastFormatted)"
        }
        
        // Notify other parts of the app about the update
        NotificationCenter.default.post(
            name: .didUpdateChapterRange,
            object: nil,
            userInfo: ["chapterRange": chapterRange]
        )
    }
    
    private func loadChapterRange() {
        // Load existing chapter data from JSON file and update range
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsDirectory.appendingPathComponent("chapters.json")
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let data = try Data(contentsOf: fileURL)
                    if let chapters = try JSONSerialization.jsonObject(with: data) as? [String: [String: String]] {
                        let urlDict = ChapterExtractionManager.extractURLs(from: chapters)
                        updateChapterRange(from: urlDict)
                    }
                } catch {
                    print("Error loading chapter data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadMangaMetadata() {
        // Load existing metadata from JSON file
        if let metadata = MetadataExtractionManager.loadMangaMetadata() {
            self.mangaMetadata = metadata
        }
    }
    
    // Clear JSON Cache when browser is opened
    private func clearJSONCache() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let chaptersFile = documentsDirectory.appendingPathComponent("chapters.json")
        let metadataFile = documentsDirectory.appendingPathComponent("manga_metadata.json")
        
        // Clear chapters.json
        if fileManager.fileExists(atPath: chaptersFile.path) {
            do {
                try "".write(to: chaptersFile, atomically: true, encoding: .utf8)
            } catch {
                print("Error clearing chapters.json: \(error)")
            }
        }
        
        // Clear manga_metadata.json
        if fileManager.fileExists(atPath: metadataFile.path) {
            do {
                try "".write(to: metadataFile, atomically: true, encoding: .utf8)
            } catch {
                print("Error clearing manga_metadata.json: \(error)")
            }
        }
        
        // Reset UI state
        bothJSONsExist = false
        containsChapter = false
        chapterRange = "0-0-0"
        mangaMetadata = nil
    }
    
    private func checkJSONsExist() {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let chaptersFile = documentsDirectory.appendingPathComponent("chapters.json")
            let metadataFile = documentsDirectory.appendingPathComponent("manga_metadata.json")
            
            // Check if files exist and have content
            let chaptersExists = fileManager.fileExists(atPath: chaptersFile.path)
            let metadataExists = fileManager.fileExists(atPath: metadataFile.path)
            
            var chaptersHasContent = false
            var metadataHasContent = false
            
            if chaptersExists {
                do {
                    let chaptersData = try Data(contentsOf: chaptersFile)
                    chaptersHasContent = !chaptersData.isEmpty
                    if !chaptersHasContent {
                    }
                } catch {
                    print("Error reading chapters.json: \(error)")
                }
            }
            
            if metadataExists {
                do {
                    let metadataData = try Data(contentsOf: metadataFile)
                    metadataHasContent = !metadataData.isEmpty
                    if !metadataHasContent {
                    }
                } catch {
                    print("Error reading manga_metadata.json: \(error)")
                }
            }
            
            bothJSONsExist = chaptersHasContent && metadataHasContent
        }
    }
    
    private func downloadCoverImage(from urlString: String?) -> Data? {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let imageData = try Data(contentsOf: url)
            return imageData
        } catch {
            print("Error downloading cover image: \(error)")
            return nil
        }
    }
    
    private func addTitleToLibrary() {
        isAddingTitle = true
        addTitleError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "FileError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
                }
                
                // Load chapters
                let chaptersFile = documentsDirectory.appendingPathComponent("chapters.json")
                if !fileManager.fileExists(atPath: chaptersFile.path) {
                    throw NSError(domain: "FileError", code: 2, userInfo: [NSLocalizedDescriptionKey: "chapters.json file not found"])
                }
                
                let chaptersData = try Data(contentsOf: chaptersFile)
                if chaptersData.isEmpty {
                    throw NSError(domain: "DataError", code: 3, userInfo: [NSLocalizedDescriptionKey: "chapters.json is empty"])
                }
                
                // Parse the JSON to understand its structure
                let jsonObject = try JSONSerialization.jsonObject(with: chaptersData, options: [])
                var chapters: [Chapter] = []
                
                if let jsonArray = jsonObject as? [[String: Any]] {
                    // This is the format saved by saveChaptersToJSON
                    for chapterDict in jsonArray {
                        if let chapterNumber = chapterDict["chapter_number"] as? Double,
                           let url = chapterDict["url"] as? String {
                            
                            let title = chapterDict["title"] as? String
                            let uploadDate = chapterDict["upload_date"] as? String
                            
                            let chapter = Chapter(
                                chapterNumber: chapterNumber,
                                url: url,
                                title: title,
                                uploadDate: uploadDate
                            )
                            chapters.append(chapter)
                        }
                    }
                } else if let chapterDict = jsonObject as? [String: [String: String]] {
                    // This is the original dictionary format
                    chapters = chapterDict.compactMap { key, value -> Chapter? in
                        guard let chapterNumber = Double(key),
                              let url = value["url"] else {
                            return nil
                        }
                        return Chapter(
                            chapterNumber: chapterNumber,
                            url: url,
                            title: value["title"],
                            uploadDate: value["upload_date"]
                        )
                    }
                    .sorted { $0.chapterNumber > $1.chapterNumber } // Sort in descending order
                } else {
                    throw NSError(domain: "DataError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown chapters.json format"])
                }
                
                if chapters.isEmpty {
                    throw NSError(domain: "DataError", code: 5, userInfo: [NSLocalizedDescriptionKey: "No valid chapters found"])
                }
                
                // Load metadata
                let metadataFile = documentsDirectory.appendingPathComponent("manga_metadata.json")
                if !fileManager.fileExists(atPath: metadataFile.path) {
                    throw NSError(domain: "FileError", code: 6, userInfo: [NSLocalizedDescriptionKey: "manga_metadata.json file not found"])
                }
                
                let metadataData = try Data(contentsOf: metadataFile)
                if metadataData.isEmpty {
                    throw NSError(domain: "DataError", code: 7, userInfo: [NSLocalizedDescriptionKey: "manga_metadata.json is empty"])
                }
                
                let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] ?? [:]
                if metadata.isEmpty {
                    throw NSError(domain: "DataError", code: 8, userInfo: [NSLocalizedDescriptionKey: "No metadata found in manga_metadata.json"])
                }
                
                // Extract title, author, and status from metadata
                let title = metadata["title"] as? String ?? "Unknown Title"
                let author = metadata["author"] as? String ?? "Unknown Author"
                let status = metadata["status"] as? String ?? "unknown"
                                
                // Download cover image (async with timeout)
                let coverImageUrl = metadata["title_image"] as? String
                var coverImageData: Data? = nil
                
                if let imageUrl = coverImageUrl, let url = URL(string: imageUrl) {
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        if let data = data, error == nil {
                            coverImageData = data
                        } else {
                            print("Error downloading cover image: \(error?.localizedDescription ?? "Unknown error")")
                        }
                        semaphore.signal()
                    }.resume()
                    
                    // Wait for download with timeout (5 seconds)
                    _ = semaphore.wait(timeout: .now() + 5.0)
                }
                
                // CAPTURE CURRENT URL
                let currentURL = self.urlString
                
                // Create new title
                let newTitle = Title(
                    title: title,
                    author: author,
                    status: status,
                    coverImageData: coverImageData,
                    chapters: chapters,
                    metadata: metadata,
                    sourceURL: currentURL
                )
                
                // Save title to documents directory
                let titlesDirectory = documentsDirectory.appendingPathComponent("Titles")
                if !fileManager.fileExists(atPath: titlesDirectory.path) {
                    try fileManager.createDirectory(at: titlesDirectory, withIntermediateDirectories: true)
                }
                
                let titleFile = titlesDirectory.appendingPathComponent("\(newTitle.id.uuidString).json")
                let titleData = try JSONEncoder().encode(newTitle)
                try titleData.write(to: titleFile)
                
                // Notify LibraryView to refresh and show success
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .titleAdded, object: nil)
                    NotificationCenter.default.post(
                        name: .titleAddedSuccess,
                        object: nil,
                        userInfo: ["title": title, "author": author]
                    )
                    self.isAddingTitle = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.addTitleError = "Error adding title: \(error.localizedDescription)"
                    self.isAddingTitle = false
                    print("Error adding title: \(error)")
                }
            }
        }
    }
}

// MARK: WebView Wrapper
struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No need to reload on update
    }
}

// MARK: Coordinator with Chapter Detection
class WebViewCoordinator: NSObject, WKNavigationDelegate {
    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?
    private var loadingObserver: NSKeyValueObservation?

    func attachObservers(to webView: WKWebView) {
        // Observe navigation state
        backObserver = webView.observe(\.canGoBack, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
        
        forwardObserver = webView.observe(\.canGoForward, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
        
        loadingObserver = webView.observe(\.isLoading, options: [.new]) { webView, _ in
            self.postNavigationUpdate(webView: webView)
        }
    }

    private func postNavigationUpdate(webView: WKWebView, error: String? = nil) {
        var userInfo: [String: Any] = [
            "canGoBack": webView.canGoBack,
            "canGoForward": webView.canGoForward,
            "currentURL": webView.url as Any,
            "isLoading": webView.isLoading
        ]
        
        if let error = error {
            userInfo["error"] = error
        }
        
        NotificationCenter.default.post(
            name: .didUpdateWebViewNav,
            object: nil,
            userInfo: userInfo
        )
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        postNavigationUpdate(webView: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        postNavigationUpdate(webView: webView)
        
        // Check for chapter word when page finishes loading
        ChapterDetectionManager.checkForChapterWord(in: webView) { containsChapter in
            NotificationCenter.default.post(
                name: .didFindChapterWord,
                object: nil,
                userInfo: ["containsChapter": containsChapter]
            )
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Handle error -999 (cancelled navigation) gracefully
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
            // This is a cancelled request, not a real error - just update navigation state
            postNavigationUpdate(webView: webView)
        } else {
            // This is a real error that should be shown to the user
            postNavigationUpdate(webView: webView, error: error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Handle error -999 (cancelled navigation) gracefully
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
            // This is a cancelled request, not a real error
            postNavigationUpdate(webView: webView)
        } else {
            // This is a real error that should be shown to the user
            postNavigationUpdate(webView: webView, error: error.localizedDescription)
        }
    }
    
    // Optional: Handle navigation decisions to prevent some cancellations
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation by default
        decisionHandler(.allow)
    }
}

// Optional: Create a helper function for user agent switching
extension WebViewUserAgentManager {
    static func withDesktopUserAgent<T>(webView: WKWebView, operation: @escaping (@escaping (T?) -> Void) -> Void, completion: @escaping (T?) -> Void) {
        let originalUserAgent = webView.customUserAgent
        setDesktopUserAgent(for: webView)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            operation { result in
                // Restore user agent
                if let originalUserAgent = originalUserAgent {
                    webView.customUserAgent = originalUserAgent
                } else {
                    setMobileUserAgent(for: webView)
                }
                completion(result)
            }
        }
    }
}

// BrowserView

#Preview {
    ContentView()
}
