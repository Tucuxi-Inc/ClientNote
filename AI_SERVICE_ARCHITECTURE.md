# AI Service Architecture Documentation

## Overview

This document describes the new AI service architecture that replaced the previous LocalAI/llamafile implementation. The new system provides three AI service options:

1. **Ollama (Local)** - Free local AI via third-party Ollama app
2. **OpenAI (User API Key)** - Free tier using user's own OpenAI API key  
3. **OpenAI (Subscription)** - Paid tier using developer's OpenAI API key

## Architecture Components

### Core Protocols & Types

#### `AIService` Protocol
```swift
protocol AIService {
    func sendMessage(_ message: String, model: String) async throws -> String
    func listModels() async throws -> [String]
    func isAvailable() async -> Bool
    var serviceType: AIServiceType { get }
}
```

#### `AIServiceType` Enum
```swift
enum AIServiceType: String, CaseIterable {
    case ollama = "Ollama (Local)"
    case openAIUser = "OpenAI (Your API Key)"
    case openAISubscription = "OpenAI (Subscription)"
}
```

### Service Implementations

#### `OllamaService`
- **Location**: `ClientNote/Services/OllamaService.swift`
- **Dependencies**: OllamaKit
- **Features**:
  - Connects to local Ollama server (localhost:11434)
  - Checks for Ollama app installation
  - Provides model management through Ollama
  - Supports streaming responses

#### `OpenAIService`
- **Location**: `ClientNote/Services/OpenAIService.swift`
- **Features**:
  - Supports both user API keys and developer API keys
  - OpenAI Chat Completions API integration
  - Model listing and availability checking
  - Error handling for API failures

### Management Layer

#### `AIServiceManager`
- **Location**: `ClientNote/Services/AIServiceManager.swift`
- **Responsibilities**:
  - Service selection and initialization
  - Subscription status monitoring
  - API key management (via KeychainManager)
  - Service availability checking
  - Automatic service selection based on user preferences

#### `AIBackendAdapter`
- **Location**: `ClientNote/Models/AIBackendAdapter.swift`
- **Purpose**: Backward compatibility layer
- **Features**:
  - Bridges new AIService protocol with old AIBackendProtocol
  - Maintains compatibility with existing UI components
  - Handles legacy backend type mapping

## Service Selection Logic

The system automatically selects the best available service in this priority order:

1. **OpenAI (Subscription)** - If user has active subscription/purchase AND developer key is available
2. **OpenAI (User API Key)** - If user has provided their own OpenAI API key
3. **Ollama (Local)** - Default fallback option

## Subscription Integration

### IAPManager Integration
- Uses existing `IAPManager.shared` for subscription status checking
- Monitors `hasFullAccess` and `hasActiveSubscription` properties
- Automatically updates available services when subscription status changes

### Subscription Products
- Weekly, Monthly, Quarterly, Yearly subscriptions
- One-time "Full Unlock" purchase
- Both grant access to premium OpenAI service

## Security & Key Management

### KeychainManager
- **Location**: `ClientNote/Utils/KeychainManager.swift`
- **Key Types**:
  - `.openAIUserKey` - User's personal OpenAI API key
  - `.openAIDeveloperKey` - App developer's OpenAI API key (for subscription service)

### Developer Key Setup
```swift
// In AIServiceManager.swift - Replace before release
private let developerOpenAIKey = "sk-your-actual-openai-api-key-here"
```

## User Interface Integration

### Settings Views
- **AIServiceSettingsView**: Main service selection interface
- **PurchaseView**: Subscription management (existing)
- **GeneralView**: Backend preferences (compatibility layer)

### Service Status Display
- Shows current service type and availability
- Provides setup instructions for each service type
- Handles error states and fallbacks

## Migration from Old System

### Removed Components
- ✅ `LocalAIBackend.swift` - Deleted
- ✅ `LocalAIWatchdog.swift` - Deleted  
- ✅ `LlamaFileBackend.swift` - Deleted
- ✅ All LocalAI/llamafile build scripts and binaries

### Backward Compatibility
- Old `AIBackend` enum maintained for existing preferences
- `AIBackendManager` still exists but delegates to `AIServiceManager`
- Existing UI components continue to work without changes

## Configuration

### Default Settings
```swift
// In Defaults+Keys.swift
static let selectedAIServiceType = Key<AIServiceType?>("selectedAIServiceType", default: nil)
static let selectedAIBackend = Key<AIBackend>("selectedAIBackend", default: .ollamaKit)
```

### First Launch Behavior
1. System checks for available services
2. Auto-selects best available option
3. Guides user through setup if needed

## Development Setup

### Required Dependencies
- `OllamaKit` - For Ollama integration
- Existing `KeychainManager` and `IAPManager`

### Environment Setup
1. Install Ollama app for local testing
2. Add OpenAI API key to `AIServiceManager.swift`
3. Configure StoreKit for subscription testing

## Error Handling

### Service Availability
- Graceful fallback when services are unavailable
- Clear error messages for common issues
- Automatic retry mechanisms where appropriate

### API Key Validation
- Real-time validation of OpenAI API keys
- Secure storage and retrieval from keychain
- User-friendly error messages for invalid keys

## Future Enhancements

### Planned Features
- Streaming response support for all services
- Custom model configuration per service
- Usage analytics and cost tracking
- Additional AI service providers

### Extension Points
- New services can be added by implementing `AIService` protocol
- UI automatically adapts to new service types
- Subscription tiers can be extended for new features

## Testing

### Unit Tests
- Service availability checking
- API key validation
- Subscription status integration
- Backward compatibility

### Integration Tests
- End-to-end chat functionality
- Service switching
- Subscription flow testing
- Error recovery scenarios

## Troubleshooting

### Common Issues
1. **Ollama not detected**: Check if Ollama app is installed and running
2. **OpenAI API errors**: Verify API key validity and account status
3. **Subscription not recognized**: Check StoreKit connection and receipt validation
4. **Service switching fails**: Verify keychain access and service availability

### Debug Information
- Service availability status logged to console
- API errors include detailed error codes
- Subscription status changes are logged
- Service selection logic is traced in debug builds

---

*Last updated: [Current Date]*
*Version: 1.0* 