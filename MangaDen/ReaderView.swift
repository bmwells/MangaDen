//
//  ReaderView.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import SwiftUI

struct ReaderView: View {
    let chapter: Chapter
    @StateObject private var readerJava = ReaderViewJava()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            if readerJava.isLoading {
                ProgressView("Loading chapter...")
                    .scaleEffect(1.5)
            } else if let error = readerJava.error {
                VStack {
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Retry") {
                        loadChapter()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if readerJava.images.isEmpty {
                VStack {
                    Text("No Content")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("Unable to load chapter content")
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<readerJava.images.count, id: \.self) { index in
                            Image(uiImage: readerJava.images[index])
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                        }
                    }
                }
            }
        }
        .navigationTitle("Chapter \(chapter.formattedChapterNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChapter()
        }
        .onDisappear {
            readerJava.clearCache()
        }
    }
    
    private func loadChapter() {
        guard let url = URL(string: chapter.url) else {
            readerJava.error = "Invalid chapter URL"
            return
        }
        
        // Remove the await if loadChapter is not async
        readerJava.loadChapter(url: url)
    }

    
    
    
}
