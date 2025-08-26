//
//  SettingsView.swift
//  MangaDen
//
//  Created by Brody Wells on 8/25/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Dark Mode", isOn: .constant(false))
                    Toggle("Notifications", isOn: .constant(true))
                }
                
                Section(header: Text("Account")) {
                    NavigationLink("Profile", destination: Text("Profile Settings"))
                    NavigationLink("Privacy", destination: Text("Privacy Settings"))
                }
                
                Section {
                    Button(role: .destructive) {} label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // Forces iPhone-style navigation on iPad
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

