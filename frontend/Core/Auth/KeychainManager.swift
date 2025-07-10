import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.ielts.practice.app.token"

    private init() {}

    func save(token: String) {
        guard let data = token.data(using: .utf8) else {
            print("❌ KeychainManager: Unable to convert token to data")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        // Try to update an existing item first.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        // If no item was found, add a new one.
        if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                print("✅ Token saved to keychain")
            } else {
                print("❌ Failed to save token to keychain. Status: \(addStatus)")
            }
        } else if status == errSecSuccess {
            print("✅ Token updated in keychain")
        } else {
            print("❌ Failed to update token in keychain. Status: \(status)")
        }
    }

    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue!
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            guard let retrievedData = dataTypeRef as? Data,
                  let token = String(data: retrievedData, encoding: .utf8) else {
                print("❌ Failed to convert retrieved token data")
                return nil
            }
            return token
        } else {
            if status == errSecItemNotFound {
                print("ℹ️ No token found in keychain")
            } else {
                print("❌ Error retrieving token. Status: \(status)")
            }
            return nil
        }
    }

    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Error deleting token. Status: \(status)")
        }
    }
}
