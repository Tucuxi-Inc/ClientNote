import Foundation

/// Secure storage for company API keys
/// Note: In a production app, these should be stored in a more secure manner,
/// such as fetching from a secure backend service
enum CompanyAPIKeys {
    /// Company's OpenAI API key for subscription users
    /// This is obfuscated to prevent easy extraction from the binary
    private static let obfuscatedOpenAIKey = [
        "sk-m9UQzLZ7IdPNzqlF",
        "g5NlXL_JUu6CF08BA65qOd",
        "krePT3BlbkFJCOjFjngECLF",
        "TdypnLhtz3OyL8Ku9bdzP_",
        "QwhJz0AUA"
    ]
    
    /// Get the company's OpenAI API key (only for subscription users)
    static var openAIKey: String {
        // For now, just return the reconstructed key
        // The access check should be done at the service level
        return obfuscatedOpenAIKey.joined()
    }
    
    /// Check if company keys are properly configured
    static var isConfigured: Bool {
        return !obfuscatedOpenAIKey.contains("REPLACE_WITH_ACTUAL")
    }
} 