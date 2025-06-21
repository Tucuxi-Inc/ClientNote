//
//  KeychainManager.swift
//  ClientNote
//
//  Secure storage for API keys
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "ai.tucuxi.ClientNote"
    
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unhandledError(status: OSStatus)
    }
    
    enum KeyType: String {
        case openAIUserKey = "openai_user_api_key"
        case openAIDeveloperKey = "openai_developer_api_key"
    }
    
    func save(key: String, for keyType: KeyType) throws {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyType.rawValue,
            kSecValueData as String: data
        ]
        
        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func retrieve(keyType: KeyType) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyType.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return key
    }
    
    func delete(keyType: KeyType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyType.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func hasKey(keyType: KeyType) -> Bool {
        do {
            _ = try retrieve(keyType: keyType)
            return true
        } catch {
            return false
        }
    }
    
    // Convenience property for OpenAI API key
    var openAIAPIKey: String {
        get {
            return (try? retrieve(keyType: .openAIUserKey)) ?? ""
        }
        set {
            if newValue.isEmpty {
                try? delete(keyType: .openAIUserKey)
            } else {
                try? save(key: newValue, for: .openAIUserKey)
            }
        }
    }
} 