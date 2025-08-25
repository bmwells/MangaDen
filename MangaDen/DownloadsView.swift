//
//  DownloadsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import Foundation
import SwiftUI

struct DownloadsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Downloading").font(.headline)
                    
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Queue").font(.headline)
                    Text("No items in queue").foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Downloads")
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

