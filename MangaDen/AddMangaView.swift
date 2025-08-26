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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Manga")
                    .font(.title)
                    .padding(.top, 30)
                
                TextField("Paste Manga URL", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
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
                
                Spacer()
            }
            .navigationBarTitle("Add Manga", displayMode: .inline)
        }
        .sheet(isPresented: $showBrowser) {
            BrowserView()
        }
    }
}

struct AddMangaView_Previews: PreviewProvider {
    static var previews: some View {
        AddMangaView()
    }
}
