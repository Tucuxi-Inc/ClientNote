//
//  AIServiceManager.swift
//  ClientNote
//
//  Manages AI service selection and configuration
//

import Foundation
import Defaults

@MainActor
class AIServiceManager: ObservableObject {
    static let shared = AIServiceManager()
    
    @Published var currentService: AIService?
    @Published var availableServices: [AIServiceType] = []
    @Published var isConfigured: Bool = false
    @Published var status: String = "Initializing..."
    
    private let keychainManager = KeychainManager()
    private var ollamaService: OllamaService?
    private var openAIUserService: OpenAIService?
    
    
    private init() {
        print("DEBUG: AIServiceManager - INIT START")
        print("DEBUG: AIServiceManager - init() called")
        
        Task { @MainActor in
            await initialize()
        }
    }
    
    func initialize() async {
        print("DEBUG: AIServiceManager.initialize() called, current isConfigured: \(isConfigured)")
        
        status = "Checking available AI services..."
        
        // Update available services
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
        
        availableServices = services
        print("DEBUG: updateAvailableServices() completed - final services: \(services.map(\.rawValue))")
    }
    
    private func selectBestAvailableService() async {
        // Priority: User OpenAI > Ollama
        if availableServices.contains(.openAIUser) {
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

 