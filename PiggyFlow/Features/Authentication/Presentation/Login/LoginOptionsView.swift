import SwiftUI
import UIKit

struct LoginOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    @State private var navigateToHome: Bool = false
    @State private var didStartAuthFlow: Bool = false
    @State private var previousAuthInProgress: Bool = false
    @State private var isGooglePressed = false
    @State private var isApplePressed = false

    init() {}

    var body: some View {
        ZStack {
            // Background with premium ambient glow
            ZStack {
                Color.appBackground

                #if os(iOS)
                Circle()
                    .fill(Color.appGreen.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 70)
                    .offset(x: 150, y: -250)
                
                Circle()
                    .fill(Color.appGreen.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -150, y: 300)
                #endif
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Illustration with a softer premium shadow
                Image("personal_type")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 245, height: 245)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 8)
                
                Spacer().frame(height: 44)

                // Title
                Text("Welcome to PiggyFlow")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer().frame(height: 24)

                // Sign-In Options (uniform size & clean H.I.G styling)
                VStack(spacing: 14) {
                    // Google Sign-In Button
                    Button {
                        didStartAuthFlow = true
                        previousAuthInProgress = appleSignInManager.isAuthInProgress
                        guard let rootController = UIApplication.topViewController() else {
                            appleSignInManager.authErrorMessage = "Unable to open Google sign in screen."
                            return
                        }
                        appleSignInManager.signInWithGoogle(presentingViewController: rootController)
                    } label: {
                        HStack(spacing: 12) {
                            if appleSignInManager.isAuthInProgress {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                Image("google")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            }
                            Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Continue with Google")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .scaleEffect(isGooglePressed ? 0.98 : 1.0)
                        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isGooglePressed)
                    }
                    .buttonStyle(.plain)
                    .disabled(appleSignInManager.isAuthInProgress)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isGooglePressed = true }
                            .onEnded { _ in isGooglePressed = false }
                    )

                    // Apple Sign-In Button
                    Button {
                        didStartAuthFlow = true
                        previousAuthInProgress = appleSignInManager.isAuthInProgress
                        appleSignInManager.handleSignIn()
                    } label: {
                        HStack(spacing: 12) {
                            if appleSignInManager.isAuthInProgress {
                                ProgressView()
                                    .tint(Color(uiColor: .systemBackground))
                            } else {
                                Image(systemName: "applelogo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(uiColor: .systemBackground))
                            }

                            Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Sign in with Apple")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(uiColor: .systemBackground))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .scaleEffect(isApplePressed ? 0.98 : 1.0)
                        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isApplePressed)
                    }
                    .buttonStyle(.plain)
                    .disabled(appleSignInManager.isAuthInProgress)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isApplePressed = true }
                            .onEnded { _ in isApplePressed = false }
                    )
                }

                Spacer()

                // Skip Setup Clickable Text
                Button {
                    didStartAuthFlow = false
                    isUserLoggedIn = true
                    navigateToHome = true
                } label: {
                    Text("Skip Setup")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appGreen)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        }
        .alert("Authentication Error", isPresented: Binding(
            get: { appleSignInManager.authErrorMessage != nil },
            set: { if !$0 { appleSignInManager.authErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                appleSignInManager.authErrorMessage = nil
            }
        } message: {
            Text(appleSignInManager.authErrorMessage ?? "Unknown error")
        }
        .onChange(of: appleSignInManager.isAuthenticated) { _, isAuthenticated in
            if didStartAuthFlow && isAuthenticated && !appleSignInManager.isAuthInProgress {
                navigateToHome = true
            }
        }
        .onChange(of: appleSignInManager.isAuthInProgress) { _, isInProgress in
            if didStartAuthFlow && previousAuthInProgress && !isInProgress && !appleSignInManager.isAuthenticated {
                navigateToHome = false
                didStartAuthFlow = false
            }
            previousAuthInProgress = isInProgress
        }
        .onChange(of: appleSignInManager.authErrorMessage) { _, message in
            if message != nil {
                didStartAuthFlow = false
                navigateToHome = false
            }
        }
        .navigationDestination(isPresented: $navigateToHome) {
            MainTabView()
        }
    }
}

#Preview {
    LoginOptionsView()
        .environmentObject(AppleSignInManager())
}
