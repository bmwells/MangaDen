//
//  AddMangaView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct AddMangaView: View {
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
            HelpView()
        }
    }
}

// MARK: Help View
struct HelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Add Manga")
                        .font(.title2)
                        .bold()
                    
                    Text("1. Paste the manga URL directly into the text field using the clipboard button.")
                    Text("2. Or open the in-app browser to navigate to your manga site and copy the URL.")
                    
                    Image(systemName: "doc.on.clipboard")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundColor(.blue)
                        .padding(.vertical)

                    Text("When you’re ready, press **Open In-App Browser** to explore and save your manga.")
                        .padding(.bottom, 10)

                    Text("Tips:")
                        .font(.headline)
                    Text("• Make sure the URL is valid.\n• If the page doesn’t load, try refreshing.\n• You can always paste directly into the text box.")
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AddMangaView_Previews: PreviewProvider {
    static var previews: some View {
        AddMangaView()
    }
}
