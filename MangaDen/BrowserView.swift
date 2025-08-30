//
//  BrowserView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

struct BrowserView: View {
    
    @State private var showJSONViewer = false
    @State private var showMetadataView = false // New state for metadata view
    
    @State private var urlString: String = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var lastLoadTime = Date.distantPast
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var containsChapter = false
    @State private var chapterRange: String = "0-0-0"
    @State private var mangaMetadata: [String: Any]? = nil // Store metadata
    @FocusState private var isURLFieldFocused: Bool

    private let webView = WKWebView()
    private let coordinator: WebViewCoordinator

    init() {
            let coord = WebViewCoordinator()
            self.coordinator = coord
            webView.navigationDelegate = coord
            coord.attachObservers(to: webView)
            
            // Set mobile user agent by default for display
            AddMangaJAVA.setMobileUserAgent(for: webView)
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
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($isURLFieldFocused)
                .submitLabel(.go)

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

            // Chapter indicator with range
            HStack {
                HStack(spacing: 8) {
                    Text("chapter")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(containsChapter ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(containsChapter ? .green : .red)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(containsChapter ? Color.green : Color.red, lineWidth: 1)
                        )
                    
                    Text(chapterRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // MARK: Button to show metadata (replaces JSON button)
                Button(action: {
                    showMetadataView.toggle()
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(mangaMetadata != nil ? .blue : .gray)
                }
                .disabled(mangaMetadata == nil)
                
                // MARK: Button to open JSONView (keep but make secondary)
                Button(action: {
                    showJSONViewer.toggle()
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

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
            // Load a default page if no URL is specified
            if urlString.isEmpty {
                urlString = "https://google.com/"
                loadURL()
            }
            // Load existing chapter data if available
            loadChapterRange()
            // Load existing metadata if available
            loadMangaMetadata()
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
        .sheet(isPresented: $showJSONViewer) {
            JSONViewerView()
        }
        .sheet(isPresented: $showMetadataView) {
            if let metadata = mangaMetadata {
                MangaMetadataDetailView(metadata: metadata)
            }
        }
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
        
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle empty input
        if input.isEmpty {
            errorMessage = "Please enter a URL or search terms"
            showError = true
            return
        }
        
        // Set desktop user agent BEFORE loading the URL for scraping
        AddMangaJAVA.setDesktopUserAgent(for: webView)
        
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
            AddMangaJAVA.findChapterLinks(in: webView) { chapterDict in
                if let chapters = chapterDict {
                    print("Found \(chapters.count) chapters")
                    let urlDict = AddMangaJAVA.extractURLs(from: chapters)
                    self.updateChapterRange(from: urlDict)
                }
            }
        }
    }
    
    private func findMetadata() {
        // Wait a moment for the desktop transformation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AddMangaJAVA.findMangaMetadata(in: webView) { metadata in
                if let metadata = metadata {
                    self.mangaMetadata = metadata
                    print("Found manga metadata: \(metadata)")
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
                        let urlDict = AddMangaJAVA.extractURLs(from: chapters)
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
        if let metadata = AddMangaJAVA.loadMangaMetadata() {
            self.mangaMetadata = metadata
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
        
        // Restore mobile user agent for display after page loads
        AddMangaJAVA.setMobileUserAgent(for: webView)
        
        // Check for chapter word when page finishes loading
        AddMangaJAVA.checkForChapterWord(in: webView) { containsChapter in
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


extension Notification.Name {
    static let didUpdateWebViewNav = Notification.Name("didUpdateWebViewNav")
    static let didFindChapterWord = Notification.Name("didFindChapterWord")
    static let didUpdateChapterRange = Notification.Name("didUpdateChapterRange")
}

// Optional: Create a helper function for user agent switching
extension AddMangaJAVA {
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

