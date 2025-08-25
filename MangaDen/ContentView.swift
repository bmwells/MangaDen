//
//  ContentView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Library Tab
            VStack {
                Image(systemName: "books.vertical")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Library")
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            
            // Downloads Tab
            VStack {
                Image(systemName: "arrow.down.circle")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Downloads")
            }
            .tabItem {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            
            // Settings Tab
            VStack {
                Image(systemName: "gearshape")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
