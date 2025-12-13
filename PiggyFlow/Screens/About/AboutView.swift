import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            
            // App icon
            Image("onboarding_image")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            
            // App title and tagline
            VStack(spacing: 4) {
                Text("PiggyFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Smart Expense Tracker")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Developer info
            VStack(spacing: 6) {
                Text("Developed by")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Vasanth Adabala")
                    .font(.headline)
                
                Text("Copyright © 2025 Vasanth")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
