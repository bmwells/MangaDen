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
                Text("Add Title to Library")
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
                                .font(.title2)
                        }
                        .padding(.trailing, 10)
                    }
                }
                .padding(.horizontal)
                
                
                // Add from URL paste  - currently does nothing
                Button("Add") {
                }
                .buttonStyle(.bordered)
                .font(.title2)
                .padding(.horizontal)
               
                
                
                // OR divider
                Text("OR")
                    .font(.title3)
                    .foregroundColor(.gray)

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
    @State private var showCopiedAlert = false
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
                            Text("Use the In-App Browser (**Recommended**)")
                                .padding(.bottom, 15)
                        }
                        Spacer()
                    }
                    
                    // MARK: - In-App Browser Guide
                    Text("In-App Browser Guide")
                        .font(.title2)
                        .bold()
                        .underline()
                        .padding(.bottom, 5)

                    Text("• The **'Add Title'** button will turn ").font(.system(size: 18)) + Text("GREEN").foregroundColor(.green).font(.system(size: 18)) + Text(" when there is a potential title that can be added to the library.")
                        .font(.system(size: 18))

                    // Two texts in columns
                    HStack(alignment: .top) {
                        Text("• Use the title view button to check for validity of current page's title.")
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("• Use the refresh button to recheck the page for title info.")
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)

                    // Icons section
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
                    
                    
                    
                    // MARK: - Supported Sites
                    Text("Supported Sites")
                        .font(.title3)
                        .bold()
                        .underline()
                        .padding(.bottom, 20)

                    // Two columns of clickable websites
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        // Column 1
                        WebsiteButton(url: "https://mangafire.to/home", name: "MangaFire")
                        WebsiteButton(url: "https://readcomiconline.li/", name: "ReadComicOnline")
                        
                        // Column 2
                        WebsiteButton(url: "https://mangaexample4.com", name: "Manga Example 5")
                        WebsiteButton(url: "https://mangaexample5.com", name: "Manga Example 6")
                    }
                    .padding(.horizontal)
                    .padding(.bottom)

                
                    // Tips
                    Text("Tips:")
                        .padding(-4)
                        .font(.title3)
                        .bold()
                        .underline()
                        .tracking(1.5)
                    Text("• Swipe down from the top of the page to exit pages such as this one or the In-App browser")
                    Text("• If you don't see a title you'd like to read on one of the supported sites, try Googling 'read [TITLE] online' as there are typically sites that exclusively host that title and are usually compatible with the app.")
                    Text("• If you would like a site to become compatible, request it by copying the email below and sending a message to our team.")
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = "brwe47@gmail.com"
                            showCopiedAlert = true
                        }) {
                            Text("Click me to copy!")
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
                        Text("MangaDen email has been copied to your clipboard.")
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Website Button View
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
    TitleHelpView()
}
