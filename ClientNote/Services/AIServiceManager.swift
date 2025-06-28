//
//  AIServiceManager.swift
//  ClientNote
//
//  Manages AI service selection and configuration
//

import Foundation
import Combine
import Defaults

@MainActor
class AIServiceManager: ObservableObject {
    static let shared = AIServiceManager()
    
    @Published var currentService: AIService?
    @Published var availableServices: [AIServiceType] = []
    @Published var isConfigured: Bool = false
    @Published var status: String = "Initializing..."
    
    private let iapManager = IAPManager.shared
    private let keychainManager = KeychainManager()
    private var ollamaService: OllamaService?
    private var openAIUserService: OpenAIService?
    private var openAISubscriptionService: OpenAIService?
    private var cancellables = Set<AnyCancellable>()
    
    // Developer OpenAI API key (stored securely in keychain)
    // TODO: Replace with your actual OpenAI API key before release
    private let developerOpenAIKey = "sk-your-actual-openai-api-key-here"
    
    private init() {
        // Monitor subscription changes
        NotificationCenter.default.publisher(for: .subscriptionStatusChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateAvailableServices()
                }
            }
            .store(in: &cancellables)
        
        // Monitor IAP changes
        iapManager.$hasFullAccess
            .combineLatest(iapManager.$hasActiveSubscription)
            .sink { [weak self] _, _ in
                Task { @MainActor in
                    await self?.updateAvailableServices()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await initialize()
        }
    }
    
    func initialize() async {
        status = "Checking available AI services..."
        await updateAvailableServices()
        await selectBestAvailableService()
        isConfigured = true
        status = "Ready"
    }
    
    private func updateAvailableServices() async {
        var services: [AIServiceType] = []
        
        // Ollama is always available (even if not running, we can show install instructions)
        services.append(.ollama)
        
        // OpenAI with user key is available if user has saved their API key
        if keychainManager.hasKey(keyType: .openAIUserKey) {
            services.append(.openAIUser)
        }
        
        // OpenAI with subscription is available if user has active subscription
        if await hasActiveSubscription() && keychainManager.hasKey(keyType: .openAIDeveloperKey) {
            services.append(.openAISubscription)
        }
        
        availableServices = services
    }
    
    private func selectBestAvailableService() async {
        // Priority: Subscription OpenAI > User OpenAI > Ollama
        if availableServices.contains(.openAISubscription) {
            await selectService(.openAISubscription)
        } else if availableServices.contains(.openAIUser) {
            await selectService(.openAIUser)
        } else {
            await selectService(.ollama)
        }
    }
    
    func selectService(_ serviceType: AIServiceType) async {
        status = "Switching to \(serviceType.rawValue)..."
        
        switch serviceType {
        case .ollama:
            if ollamaService == nil {
                ollamaService = OllamaService()
            }
            currentService = ollamaService
            
        case .openAIUser:
            do {
                let apiKey = try keychainManager.retrieve(keyType: .openAIUserKey)
                openAIUserService = OpenAIService(apiKey: apiKey, isUserKey: true)
                currentService = openAIUserService
            } catch {
                status = "Failed to load user OpenAI key"
                return
            }
            
        case .openAISubscription:
            do {
                let apiKey = try keychainManager.retrieve(keyType: .openAIDeveloperKey)
                openAISubscriptionService = OpenAIService(apiKey: apiKey, isUserKey: false)
                currentService = openAISubscriptionService
            } catch {
                status = "Failed to load subscription OpenAI key"
                return
            }
        }
        
        // Save selection
        Defaults[.selectedAIServiceType] = serviceType
        status = "Using \(serviceType.rawValue)"
    }
    
    func saveUserOpenAIKey(_ key: String) throws {
        try keychainManager.save(key: key, for: .openAIUserKey)
        Task { @MainActor in
            await updateAvailableServices()
        }
    }
    
    func removeUserOpenAIKey() throws {
        try keychainManager.delete(keyType: .openAIUserKey)
        Task { @MainActor in
            await updateAvailableServices()
            if currentService?.serviceType == .openAIUser {
                await selectBestAvailableService()
            }
        }
    }
    
    func setupDeveloperKey() async {
        // Store the developer key securely
        do {
            try keychainManager.save(key: developerOpenAIKey, for: .openAIDeveloperKey)
            await updateAvailableServices()
        } catch {
            print("Failed to store developer OpenAI key: \(error)")
        }
    }
    
    private func hasActiveSubscription() async -> Bool {
        // Check StoreKit for active subscription or one-time purchase
        return iapManager.hasFullAccess || iapManager.hasActiveSubscription
    }
}

enum AIServiceError: LocalizedError {
    case serviceUnavailable
    case noServiceSelected
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "The selected AI service is not available"
        case .noServiceSelected:
            return "No AI service is currently selected"
        case .invalidAPIKey:
            return "The API key is invalid or expired"
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
} 