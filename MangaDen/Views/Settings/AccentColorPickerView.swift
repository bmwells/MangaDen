//
//  AccentColorPickerView.swift
//  MangaDen
//
//  Created by Brody Wells on 10/20/25.
//

import SwiftUI

struct AccentColorPickerView: View {
    @Binding var selectedColor: String
    let currentColor: String
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                //Grid of color options
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Color.accentColorOptions, id: \.name) { colorOption in
                        Button(action: {
                            selectedColor = colorOption.name
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    // Fixed size container for consistent layout
                                    Circle()
                                        .fill(colorOption.color)
                                        .frame(width: 65, height: 65)
                                    
                                    // Selection indicator - doesn't affect layout
                                    if selectedColor == colorOption.name {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 3)
                                            .frame(width: 65, height: 65)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 1)
                                    }
                                }
                                .frame(width: 65, height: 65)
                                
                                Text(colorOption.displayName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectedColor = currentColor
                        isPresented = false
                    }
                    .font(.title)  // Even larger font
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .font(.title.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
            }
            .padding(.top, 60)
        }
        .onAppear {
            selectedColor = currentColor
        }
    }
}

extension Color {
    // Convert color name to Color
    static func fromStorage(_ colorName: String) -> Color {
        switch colorName {
        case "blue1": return .blue
        case "blue2": return Color(red: 0.0, green: 0.5, blue: 1.0)
        case "blue3": return Color(red: 0.2, green: 0.4, blue: 0.8)
        case "purple1": return .indigo
        case "purple2": return .purple
        case "purple3": return Color(red: 0.5, green: 0.0, blue: 0.5)
        case "purple4": return Color(red: 0.6, green: 0.2, blue: 0.8)
        case "pink1": return .pink
        case "pink2": return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "red1": return .red
        case "red2": return Color(red: 0.8, green: 0.2, blue: 0.2)
        case "orange1": return .orange
        case "orange2": return Color(red: 1.0, green: 0.5, blue: 0.0)
        case "orange3": return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "yellow1": return .yellow
        case "yellow2": return Color(red: 1.0, green: 0.8, blue: 0.0)
        case "green1": return .green
        case "green2": return Color(red: 0.2, green: 0.7, blue: 0.3)
        case "teal1": return .teal
        case "teal2": return Color(red: 0.0, green: 0.5, blue: 0.5)
        case "teal3": return Color(red: 0.0, green: 0.7, blue: 0.6)
        case "teal4": return .mint
        case "teal5": return .cyan
        case "brown1": return Color(red: 0.82, green: 0.71, blue: 0.55)   // Light Tan
        case "brown2": return Color(red: 0.74, green: 0.60, blue: 0.42)   // Warm Sand
        case "brown3": return .brown                                       // Standard Brown
        case "brown4": return Color(red: 0.65, green: 0.50, blue: 0.32)   // Light Brown
        case "brown5": return Color(red: 0.45, green: 0.30, blue: 0.20)   // Medium Brown
        default: return .blue // Default fallback
        }
    }
    
    // Get all available accent colors in spectrum order
    static var accentColorOptions: [(name: String, color: Color, displayName: String)] {
        return [
            // Blues
            ("blue1", .blue, "Blue 1"),
            ("blue2", Color(red: 0.0, green: 0.5, blue: 1.0), "Blue 2"),
            ("blue3", Color(red: 0.2, green: 0.4, blue: 0.8), "Blue 3"),
            
            // Purples
            ("purple1", .indigo, "Purple 1"),
            ("purple2", .purple, "Purple 2"),
            ("purple3", Color(red: 0.5, green: 0.0, blue: 0.5), "Purple 3"),
            ("purple4", Color(red: 0.6, green: 0.2, blue: 0.8), "Purple 4"),
            
            // Pinks
            ("pink1", .pink, "Pink 1"),
            ("pink2", Color(red: 1.0, green: 0.4, blue: 0.7), "Pink 2"),
            
            // Reds
            ("red1", .red, "Red 1"),
            ("red2", Color(red: 0.8, green: 0.2, blue: 0.2), "Red 2"),
            
            // Oranges
            ("orange1", .orange, "Orange 1"),
            ("orange2", Color(red: 1.0, green: 0.5, blue: 0.0), "Orange 2"),
            ("orange3", Color(red: 1.0, green: 0.6, blue: 0.0), "Orange 3"),
            
            // Yellows
            ("yellow1", .yellow, "Yellow 1"),
            ("yellow2", Color(red: 1.0, green: 0.8, blue: 0.0), "Yellow 2"),
            
            // Greens
            ("green1", .green, "Green 1"),
            ("green2", Color(red: 0.2, green: 0.7, blue: 0.3), "Green 2"),
            
            // Teals
            ("teal1", .teal, "Teal 1"),
            ("teal2", Color(red: 0.0, green: 0.5, blue: 0.5), "Teal 2"),
            ("teal3", Color(red: 0.0, green: 0.7, blue: 0.6), "Teal 3"),
            ("teal4", .mint, "Teal 4"),
            ("teal5", .cyan, "Teal 5"),
            
            // Browns
            ("brown1", Color(red: 0.82, green: 0.71, blue: 0.55), "Brown 1"),
            ("brown2", Color(red: 0.74, green: 0.60, blue: 0.42), "Brown 2"),
            ("brown3", .brown, "Brown 3"),
            ("brown4", Color(red: 0.65, green: 0.50, blue: 0.32), "Brown 4"),
            ("brown5", Color(red: 0.45, green: 0.30, blue: 0.20), "Brown 5")
        ]
    }
}

#Preview {
    ContentView()
}
