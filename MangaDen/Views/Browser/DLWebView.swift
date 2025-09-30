//
//  DLWebView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/26/25.
//

import SwiftUI
import WebKit

struct DLWebView: UIViewRepresentable {
    @Binding var url: URL?
    let webView: WKWebView

    init(url: Binding<URL?>, webView: WKWebView = WKWebView()) {
        self._url = url
        self.webView = webView
    }

    func makeUIView(context: Context) -> WKWebView {
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = url {
            uiView.load(URLRequest(url: url))
        }
    }

    // MARK: Navigation functions
    func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    func reload() {
        webView.reload()
    }
}
