import Foundation
import StoreKit
import SwiftUI

// Product identifiers
enum IAPProduct: String, CaseIterable {
    // Subscription options
    case oneWeekSubscription = "ai.tucuxi.ClientNote.subscription.weekly"
    case oneMonthSubscription = "ai.tucuxi.ClientNote.subscription.monthly"
    case threeMonthSubscription = "ai.tucuxi.ClientNote.subscription.quarterly"
    case yearlySubscription = "ai.tucuxi.ClientNote.subscription.yearly"
    
    // One-time purchase
    case fullUnlock = "ai.tucuxi.ClientNote.fullUnlock"
    
    // Free trial
    case freeTrial = "com.eunitm.ClientNote.freeTrial"
    
    var displayName: String {
        switch self {
        case .oneWeekSubscription: return "1-Week Plan"
        case .oneMonthSubscription: return "1-Month Plan"
        case .threeMonthSubscription: return "3-Month Plan"
        case .yearlySubscription: return "1-Year Plan"
        case .fullUnlock: return "One-Time Purchase"
        case .freeTrial: return "Free Trial"
        }
    }
    
    var price: String {
        switch self {
        case .oneWeekSubscription: return "$6.99"
        case .oneMonthSubscription: return "$19.99"
        case .threeMonthSubscription: return "$49.99"
        case .yearlySubscription: return "$169.00"
        case .fullUnlock: return "$249.00"
        case .freeTrial: return "Free"
        }
    }
    
    var description: String {
        switch self {
        case .oneWeekSubscription: return "7 days, with 3-day free trial"
        case .oneMonthSubscription: return "30 days, with 7-day free trial"
        case .threeMonthSubscription: return "90 days, with 7-day free trial"
        case .yearlySubscription: return "365 days, with 7-day free trial"
        case .fullUnlock: return "Use of all features for an unlimited time"
        case .freeTrial: return "Try all features for 7 days"
        }
    }
    
    var isSubscription: Bool {
        switch self {
        case .fullUnlock:
            return false
        default:
            return true
        }
    }
}

// Trial duration in days
let trialDurationInDays: Double = 7

@MainActor
class IAPManager: ObservableObject {
    // Static shared instance accessible throughout the app
    public static let shared = IAPManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptions: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Access flags
    @Published var hasFullAccess: Bool = false
    @Published var hasActiveSubscription: Bool = false
    @Published var subscriptionExpirationDate: Date? = nil
    
    // For debugging/history
    @Published var hasActiveFreeTrial: Bool = false
    @Published var trialExpirationDate: Date? = nil
    
    // Track trial usage - using AppStorage to persist across app launches
    @AppStorage("hasUsedWeeklyTrial") private var hasUsedWeeklyTrial = false
    @AppStorage("hasUsedMonthlyTrial") private var hasUsedMonthlyTrial = false
    @AppStorage("hasUsedQuarterlyTrial") private var hasUsedQuarterlyTrial = false
    @AppStorage("hasUsedYearlyTrial") private var hasUsedYearlyTrial = false
    
    private var productsLoaded = false
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        self.products = []
        self.purchasedProductIDs = Set<String>()
        
        Task {
            await updatePurchasedProducts()
            await loadProducts()
            updateListenerTask = listenForTransactions()
            
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                await setupTestTransactions()
            }
            #endif
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    /// Load available products
    @MainActor
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            /*
            #if DEBUG
            print("Loading products from StoreKit...")
            #endif
            */
            
            // Get all product IDs from our enum
            let productIDs = Set(IAPProduct.allCases.map { $0.rawValue })
            
            /*
            #if DEBUG
            print("Product IDs to load: \(productIDs)")
            #endif
            */
            
            // Add timeout protection and retry logic for App Store review
            let storeProducts = try await withTimeout(seconds: 15) {
                try await Product.products(for: productIDs)
            }
            
            /*
            #if DEBUG
            print("Loaded \(storeProducts.count) products from StoreKit")
            for product in storeProducts {
                print("- \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            #endif
            */
            
            // Update our products array and separate subscriptions for easier access
            self.products = storeProducts
            self.subscriptions = storeProducts.filter { product in
                if product.type == .autoRenewable {
                    return true
                }
                return false
            }
            
            if storeProducts.isEmpty {
                /*
                #if DEBUG
                print("WARNING: No products were loaded from StoreKit")
                #endif
                */
                errorMessage = "Unable to load subscription options. Please check your internet connection and try again."
            } else {
                errorMessage = nil
            }
        } catch {
            /*
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
            */
            
            // Provide more user-friendly error messages
            if error is StoreError && (error as! StoreError) == .timeout {
                errorMessage = "Loading subscription options is taking longer than expected. Please check your internet connection and try again."
            } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("internet") {
                errorMessage = "Network error: Please check your internet connection and try again."
            } else if error.localizedDescription.contains("store") || error.localizedDescription.contains("StoreKit") {
                errorMessage = "App Store connection error. Please try again in a moment."
            } else {
                errorMessage = "Unable to load subscription options. Please try again."
            }
            
            products = []
            subscriptions = []
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    
    /// Purchase a product
    @MainActor
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            /*
            #if DEBUG
            print("Attempting to purchase \(product.id)")
            
            // Check if StoreKit configuration is properly set up
            print("StoreKit environment check:")
            print("- Products loaded: \(products.count)")
            
            // Force sync with App Store first to ensure the connection works
            print("Syncing with App Store...")
            try? await AppStore.sync()
            #endif
            */
            
            // We're removing the custom trial usage check since the App Store handles this
            // Apple's StoreKit already ensures users only get one free trial per subscription type
            
            // Actual purchase code
            let result = try await product.purchase()
            
            /*
            #if DEBUG
            print("Purchase result: \(result)")
            #endif
            */
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                switch verification {
                case .verified(let transaction):
                    // Successful purchase
                    /*
                    #if DEBUG
                    print("Transaction verified: \(transaction.id)")
                    #endif
                    */
                    
                    // We'll still mark the trial as used for our local tracking
                    // but we won't block purchases based on this anymore
                    if product.subscription != nil {
                        markTrialAsUsed(for: product.id)
                    }
                    
                    // Update the purchased product IDs
                    purchasedProductIDs.insert(transaction.productID)
                    
                    // Finish the transaction and update UI
                    await transaction.finish()
                    await updatePurchasedProducts()
                    
                case .unverified(_, let verificationError):
                    // Verification failed
                    errorMessage = "Purchase verification failed: \(verificationError.localizedDescription)"
                    /*
                    #if DEBUG
                    print("Transaction verification failed: \(verificationError)")
                    #endif
                    */
                }
                
            case .userCancelled:
                /*
                #if DEBUG
                print("User cancelled the purchase")
                #endif
                */
                break
                
            case .pending:
                errorMessage = "Purchase is pending approval"
                /*
                #if DEBUG
                print("Purchase is pending approval")
                #endif
                */
                
            @unknown default:
                errorMessage = "Unknown purchase result"
                /*
                #if DEBUG
                print("Unknown purchase result")
                #endif
                */
            }
        } catch {
            // Handle any error during purchase
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            /*
            #if DEBUG
            print("Purchase error: \(error)")
            #endif
            */
        }
        
        isLoading = false
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            // print("Failed to restore purchases: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Transaction Management
    
    /// Listen for transactions from App Store
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in StoreKit.Transaction.updates {
                await self.handle(updatedTransaction: result)
            }
        }
    }
    
    /// Handle updated transactions
    @MainActor
    private func handle(updatedTransaction result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else {
            // Transaction not verified, don't provide content
            return
        }
        
        // Update the purchased products
        purchasedProductIDs.insert(transaction.productID)
        
        // Handle different product types
        if transaction.productID == IAPProduct.fullUnlock.rawValue {
            // Full unlock
            hasFullAccess = true
        } else if IAPProduct.allCases.contains(where: { $0.rawValue == transaction.productID && $0.isSubscription }) {
            // Subscription product
            hasActiveSubscription = true
            
            // Set expiration date based on subscription renewal
            if let expirationDate = transaction.expirationDate {
                subscriptionExpirationDate = expirationDate
                hasActiveSubscription = Date() < expirationDate
            }
        }
        
        // Finish the transaction
        await transaction.finish()
    }
    
    /// Update the list of purchased products
    @MainActor
    func updatePurchasedProducts() async {
        // Reset status
        hasFullAccess = false
        hasActiveSubscription = false
        hasActiveFreeTrial = false
        subscriptionExpirationDate = nil
        trialExpirationDate = nil
        
        // Get the current entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // Add the product to our purchased products
                purchasedProductIDs.insert(transaction.productID)
                
                // Check if this is the full unlock product
                if transaction.productID == IAPProduct.fullUnlock.rawValue {
                    hasFullAccess = true
                }
                
                // Check if this is a subscription product
                if IAPProduct.allCases.contains(where: { $0.rawValue == transaction.productID && $0.isSubscription }) {
                    // Check if the subscription is still active
                    if let expirationDate = transaction.expirationDate {
                        if Date() < expirationDate {
                            // Subscription is active
                            hasActiveSubscription = true
                            subscriptionExpirationDate = expirationDate
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Access Control
    
    /// Check if the user has access to premium features
    func hasAccess() -> Bool {
        // User has access if they have purchased the lifetime unlock
        // OR they have an active subscription
        return hasFullAccess || hasActiveSubscription
    }
    
    /// Get time remaining in trial or subscription
    func timeRemainingInTrial() -> String? {
        guard let expirationDate = subscriptionExpirationDate ?? trialExpirationDate else {
            return nil
        }
        
        let now = Date()
        if now >= expirationDate {
            return "Expired"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour], from: now, to: expirationDate)
        
        if let days = components.day, let hours = components.hour {
            if days > 0 {
                return "\(days) day\(days == 1 ? "" : "s") remaining"
            } else if hours > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
            } else {
                return "Less than an hour remaining"
            }
        }
        
        return nil
    }
    
    // MARK: - Product Retrieval
    
    /// Get a specific product by type
    func getProduct(for productType: IAPProduct) -> Product? {
        return products.first { product in
            product.id == productType.rawValue
        }
    }
    
    #if DEBUG
    @MainActor
    private func setupTestTransactions() async {
        // Clear any pending transactions for testing
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
        
        print("StoreKit test environment ready")
        print("Test products configured:")
        for product in self.products {
            print("- \(product.id): \(product.displayName) - \(product.displayPrice)")
        }
        
        // Print purchase status for debugging
        print("Product purchased status:")
        print("- oneWeekSubscription: \(self.purchasedProductIDs.contains(IAPProduct.oneWeekSubscription.rawValue))")
        print("- oneMonthSubscription: \(self.purchasedProductIDs.contains(IAPProduct.oneMonthSubscription.rawValue))")
        print("- threeMonthSubscription: \(self.purchasedProductIDs.contains(IAPProduct.threeMonthSubscription.rawValue))")
        print("- yearlySubscription: \(self.purchasedProductIDs.contains(IAPProduct.yearlySubscription.rawValue))")
        print("- fullUnlock: \(self.purchasedProductIDs.contains(IAPProduct.fullUnlock.rawValue))")
        
        // Uncomment this line to simulate owning a product during testing
        // self.purchasedProductIDs.insert(IAPProduct.oneWeekSubscription.rawValue)
    }
    
    /// Simulate a successful purchase (for development/testing only)
    @MainActor
    func simulatePurchase(for product: IAPProduct) async {
        isLoading = true
        errorMessage = nil
        
        print("Simulating purchase for \(product.rawValue)")
        
        // We're removing the check for consistency with the real purchase method
        // Apple handles free trial eligibility at the account level
        
        // Add to purchased products
        purchasedProductIDs.insert(product.rawValue)
        
        // We'll still mark the trial as used for our local tracking
        if product != .fullUnlock {
            markTrialAsUsed(for: product.rawValue)
        }
        
        // If it's a subscription, set up expiration date based on the product
        if product.isSubscription {
            let subscriptionStart = Date()
            var subscriptionDuration: DateComponents
            
            switch product {
            case .oneWeekSubscription:
                subscriptionDuration = DateComponents(day: 7)
            case .oneMonthSubscription:
                subscriptionDuration = DateComponents(month: 1)
            case .threeMonthSubscription:
                subscriptionDuration = DateComponents(month: 3)
            case .yearlySubscription:
                subscriptionDuration = DateComponents(year: 1)
            default:
                subscriptionDuration = DateComponents(day: 7)
            }
            
            subscriptionExpirationDate = Calendar.current.date(byAdding: subscriptionDuration, to: subscriptionStart)
            hasActiveSubscription = true
            
            print("Subscription will expire on: \(subscriptionExpirationDate?.description ?? "unknown")")
        }
        
        // If it's the full unlock
        if product == .fullUnlock {
            hasFullAccess = true
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        print("Simulated purchase complete for \(product.rawValue)")
        print("Access status: Full Access = \(hasFullAccess), Subscription Active = \(hasActiveSubscription)")
        
        isLoading = false
    }
    
    /// Reset all purchases (for development/testing only)
    @MainActor
    func resetPurchases() async {
        isLoading = true
        print("Resetting all purchases for testing")
        
        // Clear purchased products
        purchasedProductIDs.removeAll()
        
        // Reset access status
        hasFullAccess = false
        hasActiveSubscription = false
        subscriptionExpirationDate = nil
        hasActiveFreeTrial = false
        trialExpirationDate = nil
        
        // Reset trial usage
        hasUsedWeeklyTrial = false
        hasUsedMonthlyTrial = false
        hasUsedQuarterlyTrial = false
        hasUsedYearlyTrial = false
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        
        print("Purchase reset complete")
        isLoading = false
    }
    #endif
    
    // MARK: - Trial Usage Tracking
    
    /// Check if a trial has been used for a specific subscription
    private func hasUsedTrialForSubscription(_ productId: String) -> Bool {
        switch productId {
        case IAPProduct.oneWeekSubscription.rawValue:
            return hasUsedWeeklyTrial
        case IAPProduct.oneMonthSubscription.rawValue:
            return hasUsedMonthlyTrial
        case IAPProduct.threeMonthSubscription.rawValue:
            return hasUsedQuarterlyTrial
        case IAPProduct.yearlySubscription.rawValue:
            return hasUsedYearlyTrial
        default:
            return false
        }
    }
    
    /// Mark a trial as used for a specific subscription
    private func markTrialAsUsed(for productId: String) {
        switch productId {
        case IAPProduct.oneWeekSubscription.rawValue:
            hasUsedWeeklyTrial = true
        case IAPProduct.oneMonthSubscription.rawValue:
            hasUsedMonthlyTrial = true
        case IAPProduct.threeMonthSubscription.rawValue:
            hasUsedQuarterlyTrial = true
        case IAPProduct.yearlySubscription.rawValue:
            hasUsedYearlyTrial = true
        default:
            break
        }
    }
}

enum StoreError: Error {
    case failedVerification
    case productNotFound
    case timeout
}

// Helper function for timeout protection
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw StoreError.timeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
} 