import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var dataManager: DataManager
    
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @AppStorage("appleUsername") private var appleUsername: String = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App logo & title
            VStack(spacing: 16) {
                Image("onboarding_image")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                
                Text("PiggyFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Track your expenses effortlessly")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Apple Sign In Button
            Button(action: {
                appleSignInManager.handleSignIn()
            }) {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundColor(Color.white)
                .background(colorScheme == .dark ? Color.gray.opacity(0.1) : Color.black)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Text("Your data stays securely on your device.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .onAppear {
            appleSignInManager.checkExistingCredentials()
        }
        .onChange(of: appleSignInManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                setupUserProfile()
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func setupUserProfile() {
        if let firstName = UserDefaults.standard.string(forKey: "userFirstName"), !firstName.isEmpty {
            appleUsername = firstName
        } else if let savedAppleName = UserDefaults.standard.string(forKey: "appleUsername"), !savedAppleName.isEmpty {
            appleUsername = savedAppleName
        } else {
            appleUsername = "Apple User"
        }

        print("User profile setup: \(appleUsername)")
    }
}

#Preview {
    LoginView()
}
