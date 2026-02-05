import Foundation
import Security

/// LLM connection and configuration settings
struct LLMSettings: Codable, Equatable {
    /// OpenAI-compatible API endpoint URL
    var apiURL: String
    /// API key (stored separately in Keychain for security)
    var apiKey: String
    /// Model name (e.g., "qwen2.5:7b", "gpt-4", "claude-3")
    var model: String
    /// Temperature for generation (0.0-1.0)
    var temperature: Double
    /// Maximum tokens to generate
    var maxTokens: Int
    /// Whether LLM polishing is enabled globally
    var isEnabled: Bool
    /// Request timeout in seconds
    var timeout: TimeInterval

    static let `default` = LLMSettings(
        apiURL: "http://localhost:11434/v1",  // Ollama default
        apiKey: "",
        model: "qwen2.5:7b",
        temperature: 0.3,
        maxTokens: 512,
        isEnabled: false,
        timeout: 10.0
    )

    /// Convert to dictionary for WebSocket transmission
    func toDictionary() -> [String: Any] {
        return [
            "api_url": apiURL,
            "api_key": apiKey,
            "model": model,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "timeout": timeout
        ]
    }
}

// MARK: - Keychain Helper for API Key Storage

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case notFound
    case encodingError
}

struct KeychainHelper {
    private static let service = "com.voiceflow.llm"
    private static let account = "api_key"

    /// Save API key to Keychain
    static func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    /// Load API key from Keychain
    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    /// Delete API key from Keychain
    static func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
