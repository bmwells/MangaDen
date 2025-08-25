//
//  AddMangaView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import Foundation
import SwiftUI
import SafariServices

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
                
                Button(action: { showBrowser = true }) {
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

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

