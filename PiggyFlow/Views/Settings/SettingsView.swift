import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @AppStorage("username") private var userName: String = ""
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Profile") {
                    HStack {
                        Image("onboarding_image")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                        
                        Spacer()
                            .frame(width:24)
                        
                        Text(userName)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.gray.opacity(0.1))
                
                if appleSignInManager.isAuthenticated {
                    Section {
                        Button(role: .destructive) {
                            appleSignInManager.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                    
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                        .alert("Are you sure?", isPresented: $showDeleteAlert) {
                            Button("Delete", role: .destructive) {
                                deleteAccount()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will disconnect your Apple account and stop cloud sync. Local data will remain on your device.")
                        }
                    }
                    .listRowBackground(Color.gray.opacity(0.1))
                } else {
                    Section("Account") {
                        NavigationLink {
                            LoginView()
                                .environmentObject(appleSignInManager)
                        } label: {
                            Label("Sign in with Apple", systemImage: "applelogo")
                        }
                        .listRowBackground(Color.gray.opacity(0.1))
                    }
                }
                
                Section("Preferences") {
                    NavigationLink("About", destination: AboutView())
                        .listRowBackground(Color.gray.opacity(0.1))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
        }
    }
    
    // In your SwiftUI view where you handle account deletion
    func deleteAccount() {
        appleSignInManager.deleteAccount { success in
            if success {
                // Update UI state
                DispatchQueue.main.async {
                    // Ensure cloud sync is disabled
                    DataManager.shared.disableCloudSync()
                    // Any other UI cleanup
                }
            } else {
                // Show error to user
                print("Failed to delete account completely")
            }
        }
    }
}
