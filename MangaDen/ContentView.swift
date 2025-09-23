import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            
            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// TabBar Hider Extension
extension View {
    func hideTabBar() -> some View {
        self.background(TabBarHider())
    }
}

struct TabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return TabBarHiderViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    class TabBarHiderViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            self.tabBarController?.tabBar.isHidden = true
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            self.tabBarController?.tabBar.isHidden = false
        }
    }
}

#Preview {
    ContentView()
}

