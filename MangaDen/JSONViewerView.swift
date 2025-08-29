//
//  JSONViewerView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/29/25.
//

import SwiftUI

struct JSONViewerView: View {
    @State private var jsonContent: String = "Loading..."
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading JSON data...")
                        .padding()
                } else {
                    ScrollView {
                        Text(jsonContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Chapter Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy") {
                        UIPasteboard.general.string = jsonContent
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadJSON()
                    }
                }
            }
            .onAppear {
                loadJSON()
            }
        }
    }
    
    private func loadJSON() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsDirectory.appendingPathComponent("chapters.json")
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                        
                        if let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]) {
                            let jsonString = String(data: prettyData, encoding: .utf8) ?? "Failed to decode JSON"
                            
                            DispatchQueue.main.async {
                                self.jsonContent = jsonString
                                self.isLoading = false
                            }
                            return
                        }
                    } catch {
                        print("Error loading JSON: \(error)")
                        DispatchQueue.main.async {
                            self.jsonContent = "Error loading JSON: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.jsonContent = "No JSON data found"
                self.isLoading = false
            }
        }
    }
}
