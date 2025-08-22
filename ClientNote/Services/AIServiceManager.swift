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
    // Uses the obfuscated key from CompanyAPIKeys for security
    private var developerOpenAIKey: String {
        return CompanyAPIKeys.openAIKey
    }
    
    private init() {
        print("DEBUG: AIServiceManager - INIT START")
        print("DEBUG: AIServiceManager - init() called")
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
        
        Task { @MainActor in
            await initialize()
        }
    }
    
    func initialize() async {
        print("DEBUG: AIServiceManager.initialize() called, current isConfigured: \(isConfigured)")
        
        status = "Checking available AI services..."
        
        // Ensure company developer key is stored in keychain for subscription users
        print("DEBUG: AIServiceManager.initialize() - About to call setupDeveloperKey()")
        await setupDeveloperKey()
        print("DEBUG: AIServiceManager.initialize() - setupDeveloperKey() completed")
        
        // Always update available services to detect subscription changes
        print("DEBUG: AIServiceManager.initialize() - About to call updateAvailableServices()")
        await updateAvailableServices()
        print("DEBUG: AIServiceManager.initialize() - updateAvailableServices() completed")
        
        // Only select best service if we don't have a current service or it's no longer available
        if currentService == nil || !availableServices.contains(currentService!.serviceType) {
            print("DEBUG: AIServiceManager.initialize() - About to call selectBestAvailableService()")
            await selectBestAvailableService()
        } else {
            print("DEBUG: AIServiceManager.initialize() - Keeping current service: \(currentService?.serviceType.rawValue ?? "none")")
        }
        
        isConfigured = true
        status = "Ready"
        print("DEBUG: AIServiceManager.initialize() completed, isConfigured: \(isConfigured)")
        print("DEBUG: AIServiceManager.initialize() - Available services: \(availableServices.map(\.rawValue))")
        print("DEBUG: AIServiceManager.initialize() - Current service: \(currentService?.serviceType.rawValue ?? "none")")
    }
    
    func updateAvailableServices() async {
        print("DEBUG: updateAvailableServices() called")
        var services: [AIServiceType] = []
        
        // Ollama is always available (even if not running, we can show install instructions)
        services.append(.ollama)
        
        // OpenAI with user key is available if user has saved their API key
        if keychainManager.hasKey(keyType: .openAIUserKey) {
            services.append(.openAIUser)
        }
        
        // OpenAI with subscription is available if user has active subscription
        let hasSubscription = await hasActiveSubscription()
        let hasDeveloperKey = keychainManager.hasKey(keyType: .openAIDeveloperKey)
        let keyConfigured = CompanyAPIKeys.isConfigured
        
        print("DEBUG: Subscription check - hasSubscription: \(hasSubscription), hasDeveloperKey: \(hasDeveloperKey), keyConfigured: \(keyConfigured)")
        print("DEBUG: IAPManager.hasFullAccess: \(iapManager.hasFullAccess), hasActiveSubscription: \(iapManager.hasActiveSubscription)")
        
        if hasSubscription && hasDeveloperKey {
            services.append(.openAISubscription)
            print("DEBUG: Added .openAISubscription to available services")
        } else {
            print("DEBUG: NOT adding .openAISubscription - hasSubscription: \(hasSubscription), hasDeveloperKey: \(hasDeveloperKey)")
        }
        
        availableServices = services
        print("DEBUG: updateAvailableServices() completed - final services: \(services.map(\.rawValue))")
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
        print("DEBUG: AIServiceManager.selectService() called with: \(serviceType.rawValue)")
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
        print("DEBUG: AIServiceManager.setupDeveloperKey() called")
        
        if !CompanyAPIKeys.isConfigured {
            print("WARNING: Company API key is not properly configured!")
            return
        }
        
        // Check if key already exists
        if keychainManager.hasKey(keyType: .openAIDeveloperKey) {
            print("DEBUG: Developer key already exists in keychain")
            return
        }
        
        // Store the developer key securely
        do {
            let key = developerOpenAIKey
            print("DEBUG: Setting up developer key - length: \(key.count), starts with sk-: \(key.hasPrefix("sk-"))")
            try keychainManager.save(key: key, for: .openAIDeveloperKey)
            print("DEBUG: Developer key saved successfully to keychain")
        } catch {
            print("ERROR: Failed to store developer OpenAI key: \(error)")
        }
    }
    
    private func hasActiveSubscription() async -> Bool {
        let hasFullAccess = iapManager.hasFullAccess
        let hasActiveSubscription = iapManager.hasActiveSubscription
        let result = hasFullAccess || hasActiveSubscription
        print("DEBUG: hasActiveSubscription() - hasFullAccess: \(hasFullAccess), hasActiveSubscription: \(hasActiveSubscription), result: \(result)")
        return result
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