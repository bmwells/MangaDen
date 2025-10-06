//
//  AddMangaView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct AddTitleView: View {
    @State private var urlText: String = ""
    @State private var showBrowser = false
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Manga")
                    .font(.title)
                    .padding(.top, 30)

                ZStack {
                    // Paste Manga field
                    TextField("Paste Manga URL", text: $urlText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.trailing, 40) // space for icon

                    HStack {
                        Spacer()
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                urlText = clipboard
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        }
                        .padding(.trailing, 10)
                    }
                }
                .padding(.horizontal)
                
                
                // Add from URL paste  - currently does nothing
                Button("Add") {
                }
                .buttonStyle(.bordered)
                
                
                // OR divider
                Text("OR")
                    .font(.headline)
                    .foregroundColor(.gray)

                // In App Browser Button
                Button(action: {
                    showBrowser = true
                }) {
                    Label("Open In-App Browser", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                // Add extra space before Help button
                Spacer(minLength: 60)

                // Help Button
                Button(action: {
                    showHelp = true
                }) {
                    Image(systemName: "questionmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue) // symbol color
                            .padding(20)
                            .background(Circle().fill(Color.gray.opacity(0.2))) // gray circle
                
                }

                Spacer()
            }
        }
        // Browser sheet
        .sheet(isPresented: $showBrowser) {
            BrowserView()
        }
        // Help sheet
        .sheet(isPresented: $showHelp) {
            TitleHelpView()
        }
    }
} // AddTitleView

// MARK: Help View
struct TitleHelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { // Changed from .center to .leading
                    Text("How to Add Titles")
                        .underline()
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center) // Keep title centered
                    
                    HStack {
                        Spacer()
                        VStack(alignment: .center, spacing: 4) {
                            Text("Paste a valid title page's URL into text box")
                            Text("OR")
                                .font(.title2)
                                .bold()
                            Text("Use the In App Browser (**Recommended**)")
                        }
                        Spacer()
                    }
                    
                    Text("Tips:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Tip 1 \n• Tip 2 \n• Tip 3 \n ")
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    TitleHelpView()
}
