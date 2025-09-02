//
//  ReaderView.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import SwiftUI

struct ReaderView: View {
    let chapter: Chapter
    
    var body: some View {
        VStack {
            Text("Reader View")
                .font(.title)
                .padding()
            
            Text("Chapter \(chapter.formattedChapterNumber)")
                .font(.headline)
            
            Text("\(chapter.url)")
                .font(.headline)
            
            if let title = chapter.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            
            Text("Reader functionality will be implemented here")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Chapter \(chapter.formattedChapterNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }
}


