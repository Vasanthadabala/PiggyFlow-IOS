//
//  LoginOptions.swift
//  PiggyFlow
//
//  Created by Vasanth on 05/04/26.
//

import SwiftUI

struct AccountTypeView: View {
    @State private var selectedType: AccountType = .personal
    @State private var navigateToLoginOptions: Bool = false
    @State private var showComingSoonToast: Bool = false
    @AppStorage(AccountType.storageKey) private var storedAccountType: String = AccountType.personal.rawValue

    var body: some View {
        VStack(spacing: 0) {
            
            VStack(spacing: 10) {
                Text("Choose your account")
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("Pick the flow that matches how you want to manage\nmoney in PiggyFlow.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 24)
            
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 320, height: 320)
                
                Image(selectedType.imageAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .clipShape(Circle())
            }

            Spacer().frame(height: 16)

            Text(selectedType.title)
                .font(.system(size: 24, weight: .semibold))

            Spacer().frame(height: 12)

            HStack(spacing: 12) {
                Circle()
                    .fill(selectedType == .personal ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(selectedType == .business ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)
            }

            Spacer().frame(height: 16)

            VStack(spacing: 12) {
                accountCard(for: .personal)
                accountCard(for: .business)
            }

            Spacer()

            Button {
                guard selectedType != .business else {
                    showComingSoon()
                    return
                }
                storedAccountType = selectedType.rawValue
                navigateToLoginOptions = true
            } label: {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .onAppear {
            selectedType = AccountType(rawValue: storedAccountType) ?? .personal
        }
        .navigationDestination(isPresented: $navigateToLoginOptions) {
            LoginOptionsView(selectedType: selectedType)
        }
        .overlay(alignment: .bottom) {
            if showComingSoonToast {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Coming soon")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.86))
                )
                .foregroundColor(.white)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showComingSoonToast)
    }

    private func showComingSoon() {
        withAnimation {
            showComingSoonToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showComingSoonToast = false
            }
        }
    }

    @ViewBuilder
    private func accountCard(for type: AccountType) -> some View {
        let isSelected = selectedType == type

        HStack(spacing: 14) {
            Circle()
                .fill(isSelected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 18, height: 18)
                .padding(.leading, 4)

            Text(type.shortTitle)
                .font(.system(size: 16, weight: .semibold))

            Text(type.description)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 4)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
                storedAccountType = type.rawValue
            }
        }
    }
}

enum AccountType: String, CaseIterable {
    case personal
    case business

    static let storageKey = "selectedAccountType"

    var imageAssetName: String {
        switch self {
        case .personal:
            return "personal_type"
        case .business:
            return "business_type"
        }
    }

    var title: String {
        switch self {
        case .personal:
            return "Personal account"
        case .business:
            return "Business account"
        }
    }

    var shortTitle: String {
        switch self {
        case .personal:
            return "Personal"
        case .business:
            return "Business"
        }
    }

    var description: String {
        switch self {
        case .personal:
            return "Budget tracking, income and expenses"
        case .business:
            return "Party ledger, balances, reminders and business flow"
        }
    }
}

#Preview {
    AccountTypeView()
}
