import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            
            Tab("Home", systemImage: "house.fill"){
                HomeView()
            }
            
            Tab("Tracker", systemImage: "creditcard"){
                TrackerView()
            }
            
            Tab("Stats", systemImage: "chart.xyaxis.line"){
                StatsView()
            }
            
            Tab("Settings", systemImage: "gearshape.fill"){
                SettingsView()
            }
            
        }
        .accentColor(.green)
    }
}
