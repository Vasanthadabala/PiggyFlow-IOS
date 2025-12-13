import SwiftUI
import SwiftData
import AuthenticationServices
import CryptoKit
import Combine
import CloudKit

class AppleSignInManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: AppleUser?
    @Published var error: Error?
    
    private var currentNonce: String?
    
    struct AppleUser {
        let id: String
        let email: String?
        let firstName: String?
        let lastName: String?
    }
    
    // MARK: - Handle Apple Sign In
    func handleSignIn() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    // MARK: - Check if user already signed in
    func checkExistingCredentials() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        guard let userID = UserDefaults.standard.string(forKey: "appleUserID") else { return }
        
        appleIDProvider.getCredentialState(forUserID: userID) { [weak self] state, error in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    self?.isAuthenticated = true
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    func signOut() {
        // Reset authentication state
        isAuthenticated = false
        user = nil

        // Remove Apple Sign-In user info
        let defaults = UserDefaults.standard
        [
            "appleUserID",
            "userEmail",
            "userFirstName",
            "userLastName",
        ].forEach { defaults.removeObject(forKey: $0) }
    }
    
    func deleteAccount(completion: @escaping (Bool) -> Void) {
        // 1. Delete CloudKit data first
        deleteCloudKitData { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // 2. Complete sign out process
                self.completeAccountDeletion()
                print("✅ Account fully deleted - CloudKit data removed and sync disabled")
                completion(true)
            } else {
                print("❌ Failed to delete CloudKit data")
                completion(false)
            }
        }
    }
    
    private func completeAccountDeletion() {
        // Step 1: Reset authentication state
        isAuthenticated = false
        user = nil

        // Step 2: Remove all user data and sync flags
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "appleUserID",
            "userEmail",
            "userFirstName",
            "userLastName",
            "iCloudSyncEnabled",
            "iCloudUserID",
            "iCloudLastSyncDate",
            "ubiquityIdentityToken"
        ]
        
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        
        // Step 3: Disable iCloud sync for future
        defaults.set(false, forKey: "iCloudSyncEnabled")
        
        // Step 4: Clear SwiftData Cloud container
        DataManager.shared.cloudContainer = nil
        
        // Step 6: Clear Keychain items (if any)
        clearKeychainItems()
    }
    
    private func deleteCloudKitData(completion: @escaping (Bool) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.piggyflowlabs.PiggyFlow")
        let privateDatabase = container.privateCloudDatabase

        // ✅ Correct record types
        let expenseQuery = CKQuery(recordType: "CD_Expense", predicate: NSPredicate(value: true))
        let incomeQuery = CKQuery(recordType: "CD_Income", predicate: NSPredicate(value: true))
        
        func fetchRecords(for query: CKQuery, completion: @escaping ([CKRecord]) -> Void) {
            var fetched: [CKRecord] = []
            let op = CKQueryOperation(query: query)
            
            op.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    fetched.append(record)
                }
            }
            
            op.queryResultBlock = { result in
                switch result {
                case .success:
                    completion(fetched)
                case .failure(let error as CKError):
                    // Gracefully handle missing record types
                    if error.code == .unknownItem {
                        print("⚠️ Record type \(query.recordType) does not exist — skipping.")
                        completion([])
                    } else {
                        print("❌ Query error for \(query.recordType): \(error)")
                        completion([])
                    }
                default:
                    completion([])
                }
            }
            privateDatabase.add(op)
        }

        func deleteRecords(_ records: [CKRecord], completion: @escaping (Bool) -> Void) {
            guard !records.isEmpty else {
                completion(true)
                return
            }

            let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: records.map { $0.recordID })
            deleteOperation.modifyRecordsResultBlock = { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Successfully deleted \(records.count) records from CloudKit")
                        completion(true)
                    case .failure(let error):
                        print("❌ Failed to delete CloudKit records: \(error)")
                        completion(false)
                    }
                }
            }
            privateDatabase.add(deleteOperation)
        }

        fetchRecords(for: expenseQuery) { expenses in
            fetchRecords(for: incomeQuery) { incomes in
                deleteRecords(expenses + incomes) { success in
                    completion(success)
                }
            }
        }
    }
    
    private func clearKeychainItems() {
        // Clear any stored keychain items related to authentication
        let keychainItems = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for keychainItem in keychainItems {
            let query: [String: Any] = [kSecClass as String: keychainItem]
            SecItemDelete(query as CFDictionary)
        }
    }
    
    // MARK: - Security Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce.")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        return SHA256.hash(data: inputData).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Delegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let user = AppleUser(
                id: credential.user,
                email: credential.email,
                firstName: credential.fullName?.givenName,
                lastName: credential.fullName?.familyName
            )
            
            DispatchQueue.main.async {
                self.user = user
                self.isAuthenticated = true
                self.error = nil
                
                // Save details
                UserDefaults.standard.set(credential.user, forKey: "appleUserID")
                
                if let email = credential.email {
                    UserDefaults.standard.set(email, forKey: "userEmail")
                }
                
                if let firstName = credential.fullName?.givenName, !firstName.isEmpty {
                    UserDefaults.standard.set(firstName, forKey: "userFirstName")
                    UserDefaults.standard.set(firstName, forKey: "appleUsername")
                } else if let existing = UserDefaults.standard.string(forKey: "appleUsername") {
                    // ✅ Preserve previously saved username
                    UserDefaults.standard.set(existing, forKey: "appleUsername")
                } else {
                    // Default fallback
                    UserDefaults.standard.set("Apple User", forKey: "appleUsername")
                }
                
                if let lastName = credential.fullName?.familyName {
                    UserDefaults.standard.set(lastName, forKey: "userLastName")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error
            self.isAuthenticated = false
            print("Sign in with Apple error: \(error)")
        }
    }
}
