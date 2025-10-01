//
//  SettingsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @EnvironmentObject private var tabBarManager: TabBarManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                
                Section(header: Text("General")) {
                    Text("Version 0.5")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline) // Add this for consistent title display
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Add this for iPad
        .onAppear {
            tabBarManager.isTabBarHidden = false
        }
    }
}

