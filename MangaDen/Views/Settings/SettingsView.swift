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
            VStack(spacing: 0) {
                Form {
                    
                    // Appearance Settings
                    Section(header: Text("Appearance")) {
                        // Dark Mode
                        Toggle("Dark Mode", isOn: $isDarkMode)
                    }
                }
                
                
                
                // Version at bottom of page
                VStack {
                    Divider()
                    Text("Version 0.6")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(.bottom, 74)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            tabBarManager.isTabBarHidden = false
        }
    }
}
