import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var tabBarManager = TabBarManager()
    
    init() {
        customizeTabBar()
    }
    
    var body: some View {
        ZStack {
            // Main content - Use ZStack instead of TabView for proper layout
            Group {
                switch selectedTab {
                case 0:
                    LibraryView()
                        .environmentObject(tabBarManager)
                case 1:
                    DownloadsView()
                        .environmentObject(tabBarManager)
                case 2:
                    SettingsView()
                        .environmentObject(tabBarManager)
                default:
                    LibraryView()
                        .environmentObject(tabBarManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar at bottom
            if !tabBarManager.isTabBarHidden {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(0..<3) { index in
                            TabButton(
                                icon: tabIcon(for: index),
                                label: tabLabel(for: index),
                                isSelected: selectedTab == index,
                                isDarkMode: isDarkMode
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = index
                                    tabBarManager.isTabBarHidden = false
                                }
                            }
                            
                            // Add divider except after last item
                            if index < 2 {
                                Rectangle()
                                    .fill(isDarkMode ? Color.white.opacity(0.3) : Color.white.opacity(0.4))
                                    .frame(width: 1, height: 80)
                            }
                        }
                    }
                    .frame(height: 80)
                    .background(isDarkMode ? Color.gray.opacity(0.9) : Color.blue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environmentObject(tabBarManager)
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "books.vertical"
        case 1: return "arrow.down.circle"
        case 2: return "gearshape"
        default: return "circle"
        }
    }
    
    private func tabLabel(for index: Int) -> String {
        switch index {
        case 0: return "Library"
        case 1: return "Downloads"
        case 2: return "Settings"
        default: return "Tab"
        }
    }
    
    private func customizeTabBar() {
        UITabBar.appearance().isHidden = true
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                    .frame(height: 24)
                
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : (isDarkMode ? .white.opacity(0.7) : .white.opacity(0.6)))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
