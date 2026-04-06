//
//  LoginOptions.swift
//  PiggyFlow
//
//  Created by Vasanth on 05/04/26.
//

import SwiftUI
import UIKit

struct LoginOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    let selectedType: AccountType?
    @AppStorage(AccountType.storageKey) private var storedAccountType: String = AccountType.personal.rawValue
    @AppStorage(AppleSignInManager.loginStatusKey) private var isUserLoggedIn: Bool = false
    @State private var navigateToHome: Bool = false
    @State private var didStartAuthFlow: Bool = false
    @State private var previousAuthInProgress: Bool = false

    init(selectedType: AccountType? = nil) {
        self.selectedType = selectedType
    }

    private var resolvedAccountType: AccountType {
        selectedType ?? AccountType(rawValue: storedAccountType) ?? .personal
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(resolvedAccountType.imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .clipShape(Circle())
            
            Spacer().frame(height: 12)
            
            VStack {
                Text(resolvedAccountType == .personal ? "Personal Account" : "Business Account")
                    .font(.system(size: 24, weight: .semibold))
            }

            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.system(size: 24, weight: .semibold))

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
                                .tint(.black)
                        } else {
                            Image("google")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        }
                        Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Continue with Google")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(appleSignInManager.isAuthInProgress)

                Button {
                    didStartAuthFlow = true
                    previousAuthInProgress = appleSignInManager.isAuthInProgress
                    appleSignInManager.handleSignIn()
                } label: {
                    HStack(spacing: 12) {
                        if appleSignInManager.isAuthInProgress {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 24, height: 24)
                        }

                        Text(appleSignInManager.isAuthInProgress ? "Signing in..." : "Sign in with Apple")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(appleSignInManager.isAuthInProgress)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
            )
            .padding(.horizontal, 2)

            Spacer().frame(height: 24)

            Button {
                didStartAuthFlow = false
                isUserLoggedIn = true
                navigateToHome = true
            } label: {
                HStack(spacing: 12) {
                    Spacer()
                    Text("Skip")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green)
                )
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
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
            // Auth flow ended and it wasn't successful -> stay on login options.
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

private extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
