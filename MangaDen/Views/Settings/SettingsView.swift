//
//  SettingsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("defaultReadingDirection") private var defaultReadingDirection: ReadingDirection = .rightToLeft
    @EnvironmentObject private var tabBarManager: TabBarManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    
                    // Display Settings
                    Section(header: Text("Display")) {
                        // Dark Mode
                        Toggle("Dark Mode", isOn: $isDarkMode)
                    }
                    
                    // User Preferences
                    Section(header: Text("User Preferences")) {
                        HStack {
                            Text("Reading Direction")
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: { defaultReadingDirection = .leftToRight }) {
                                    Text("L → R")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(defaultReadingDirection == .leftToRight ? .white : .blue)
                                        .frame(width: 60, height: 32)
                                        .background(defaultReadingDirection == .leftToRight ? Color.blue : Color.clear)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle()) 
                                
                                Button(action: { defaultReadingDirection = .rightToLeft }) {
                                    Text("L ← R")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(defaultReadingDirection == .rightToLeft ? .white : .blue)
                                        .frame(width: 60, height: 32)
                                        .background(defaultReadingDirection == .rightToLeft ? Color.blue : Color.clear)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.blue, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
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
