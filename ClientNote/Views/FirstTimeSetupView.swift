import SwiftUI
import Defaults
import StoreKit

struct FirstTimeSetupView: View {
    @Binding var isPresented: Bool
    @State private var selectedService: AIServiceOption? = nil
    @State private var showingAPIKeyEntry = false
    @State private var showingSubscriptionFlow = false
    @State private var apiKey = ""
    @State private var isValidatingAPIKey = false
    @State private var errorMessage: String?
    @Environment(ChatViewModel.self) private var chatViewModel
    
    enum AIServiceOption {
        case openAI
        case ollama
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image("1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 400, maxHeight: 200)
                
                Text("Welcome to Client Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose how you'd like to power your AI assistant")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
            
            // Service Options
            VStack(spacing: 20) {
                // OpenAI Option
                ServiceOptionCard(
                    title: "Use with Cloud Based AI",
                    subtitle: "Subscription, One-Time Purchase, or Your Own API Key",
                    icon: "cloud.fill",
                    isSelected: selectedService == .openAI,
                    features: [
                        "Powered by GPT-4.1 Nano",
                        "Fast and reliable",
                        "Cloud-based processing",
                        "No local setup required"
                    ]
                ) {
                    selectedService = .openAI
                }
                
                // Ollama Option
                ServiceOptionCard(
                    title: "Use with Ollama",
                    subtitle: "Free - Processes client data only on Your Computer",
                    icon: "desktopcomputer",
                    isSelected: selectedService == .ollama,
                    features: [
                        "100% free to use",
                        "Privacy-focused (local processing)",
                        "Multiple model options",
                        "Requires Ollama app installation"
                    ]
                ) {
                    selectedService = .ollama
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Continue Button
            Button(action: handleContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedService != nil ? Color.euniPrimary : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(selectedService == nil)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 800, height: 700)
        .background(Color.euniBackground)
        .sheet(isPresented: $showingAPIKeyEntry) {
            APIKeyEntryView(
                apiKey: $apiKey,
                isValidating: $isValidatingAPIKey,
                errorMessage: $errorMessage,
                onCancel: {
                    showingAPIKeyEntry = false
                    selectedService = nil
                },
                onSubmit: validateAndSaveAPIKey
            )
        }
        .sheet(isPresented: $showingSubscriptionFlow) {
            SubscriptionView(
                onComplete: { success in
                    if success {
                        completeSetup(with: .openAISubscription)
                    } else {
                        showingSubscriptionFlow = false
                        selectedService = nil
                    }
                }
            )
        }
    }
    
    private func handleContinue() {
        switch selectedService {
        case .openAI:
            showOpenAIOptions()
        case .ollama:
            completeSetup(with: .ollama)
        case .none:
            break
        }
    }
    
    private func showOpenAIOptions() {
        // Show alert to choose between subscription and API key
        let alert = NSAlert()
        alert.messageText = "Choose Cloud AI Access Method"
        alert.informativeText = "How would you like to access cloud-based AI?"
        alert.addButton(withTitle: "Subscription or One-Time Purchase")
        alert.addButton(withTitle: "Use My Own OpenAI API Key")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            showingSubscriptionFlow = true
        case .alertSecondButtonReturn:
            showingAPIKeyEntry = true
        default:
            selectedService = nil
        }
    }
    
    private func validateAndSaveAPIKey() {
        isValidatingAPIKey = true
        errorMessage = nil
        
        Task {
            do {
                // Test the API key
                let service = OpenAIService(apiKey: apiKey)
                _ = try await service.listModels()
                
                // Save the API key
                KeychainManager.shared.openAIAPIKey = apiKey
                
                await MainActor.run {
                    completeSetup(with: .openAIUser)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Invalid API key. Please check and try again."
                    isValidatingAPIKey = false
                }
            }
        }
    }
    
    private func completeSetup(with serviceType: AIServiceType) {
        // Save the selected service
        Defaults[.selectedAIServiceType] = serviceType
        
        // Set the appropriate backend based on service type
        if serviceType == .openAIUser || serviceType == .openAISubscription {
            Defaults[.selectedAIBackend] = .openAI
        } else {
            Defaults[.selectedAIBackend] = .ollamaKit
        }
        
        // Mark first launch as complete
        Defaults[.defaultHasLaunched] = true
        
        // Initialize the service
        Task {
            await AIServiceManager.shared.selectService(serviceType)
            
            // Create initial chat
            await MainActor.run {
                if serviceType == .ollama {
                    // For Ollama, we'll need to check if models are available
                    chatViewModel.fetchModelsFromBackend()
                } else {
                    // For OpenAI, create chat with gpt-4.1-nano
                    chatViewModel.create(model: "gpt-4.1-nano")
                }
                
                // Dismiss the setup view
                isPresented = false
            }
        }
    }
}

struct ServiceOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let features: [String]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : .euniPrimary)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    HStack(spacing: 16) {
                        ForEach(features, id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.euniPrimary : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.euniPrimary : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct APIKeyEntryView: View {
    @Binding var apiKey: String
    @Binding var isValidating: Bool
    @Binding var errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Your OpenAI API Key")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your API key will be securely stored in your Mac's keychain")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isValidating)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isValidating)
                
                Button("Validate & Save") {
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || isValidating)
                
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Link("Get an API key from OpenAI", 
                 destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)
        }
        .padding(30)
        .frame(width: 500)
    }
}

struct SubscriptionView: View {
    let onComplete: (Bool) -> Void
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var purchaseError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Client Notes Premium")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Unlock OpenAI-powered documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 10)
            
            // Subscription Options
            if isLoading {
                ProgressView("Loading subscription options...")
                    .padding()
                    .frame(maxHeight: .infinity)
            } else if products.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load subscription options")
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(products.sorted(by: { p1, p2 in
                            // Sort by price descending (yearly first)
                            p1.price > p2.price
                        }), id: \.id) { product in
                            SubscriptionOptionView(product: product) {
                                Task {
                                    await purchase(product)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            
            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Other Options Section
            VStack(spacing: 12) {
                Text("Other Options")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: {
                    onComplete(false)
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back to Setup Options")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gray)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Text("You can also change this later in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(30)
        .frame(width: 600, height: 600)
        .task {
            await loadProducts()
        }
    }
    
    private func loadProducts() async {
        // Load subscription products from App Store
        do {
            let productIds = [
                "ai.tucuxi.ClientNote.subscription.weekly",
                "ai.tucuxi.ClientNote.subscription.monthly",
                "ai.tucuxi.ClientNote.subscription.quarterly",
                "ai.tucuxi.ClientNote.subscription.yearly"
            ]
            
            products = try await Product.products(for: productIds)
            isLoading = false
        } catch {
            print("Failed to load products: \(error)")
            isLoading = false
        }
    }
    
    private func purchase(_ product: Product) async {
        // Handle purchase
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Transaction is verified, grant access
                    await transaction.finish()
                    await MainActor.run {
                        onComplete(true)
                    }
                case .unverified:
                    // Transaction failed verification
                    await MainActor.run {
                        purchaseError = "Purchase could not be verified"
                    }
                }
            case .userCancelled:
                // User cancelled the purchase
                break
            case .pending:
                // Transaction is pending (e.g., parental approval)
                await MainActor.run {
                    purchaseError = "Purchase is pending approval"
                }
            @unknown default:
                await MainActor.run {
                    purchaseError = "Unknown error occurred"
                }
            }
        } catch {
            await MainActor.run {
                purchaseError = "Purchase failed: \(error.localizedDescription)"
            }
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let onPurchase: () -> Void
    
    var body: some View {
        Button(action: onPurchase) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(getProductDescription(product))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.euniPrimary)
                    
                    if let period = getSubscriptionPeriod(product) {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color.euniFieldBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.euniBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                // Add hover effect if needed
            }
        }
    }
    
    private func getProductDescription(_ product: Product) -> String {
        if product.id.contains("weekly") {
            return "Free trial of 3 days included"
        } else if product.id.contains("monthly") {
            return "Free trial of 7 days included"
        } else if product.id.contains("quarterly") {
            return "Free trial of 7 days included"
        } else if product.id.contains("yearly") {
            return "Free trial of 7 days included • Best value"
        }
        return product.description
    }
    
    private func getSubscriptionPeriod(_ product: Product) -> String? {
        if product.id.contains("weekly") {
            return "per week"
        } else if product.id.contains("monthly") {
            return "per month"
        } else if product.id.contains("quarterly") {
            return "per 3 months"
        } else if product.id.contains("yearly") {
            return "per year"
        }
        return nil
    }
}

#Preview {
    FirstTimeSetupView(isPresented: .constant(true))
        // Preview placeholder - requires proper initialization
} 