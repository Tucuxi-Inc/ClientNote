import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var iapManager = IAPManager.shared
    @State private var showingRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showingRestoreSuccess = false
    @State private var showingErrorAlert = false
    
    /* 
    #if DEBUG
    @AppStorage("bypassAccessControl") private var bypassAccessControl = false
    #endif
    */
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                /*
                #if DEBUG
                if bypassAccessControl {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("DEVELOPMENT MODE: Access Control Bypassed")
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Disable Bypass") {
                            bypassAccessControl = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                #endif
                */
                
                // Header
                VStack(alignment: .center, spacing: 16) {
                    Image("1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .padding(.top, 16)
                    
                    Text("Euni™ - Easy Therapy Notes")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.euniText)
                    
                    Text("Professional tools for therapy documentation")
                        .font(.title3)
                        .foregroundColor(Color.euniSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                // Error messages - More prominent placement
                if let errorMessage = iapManager.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            iapManager.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeInOut, value: iapManager.errorMessage != nil)
                    .onAppear {
                        // Auto-dismiss after 8 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            iapManager.errorMessage = nil
                        }
                    }
                }
                
                // Access Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: iapManager.hasAccess() ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(iapManager.hasAccess() ? Color.euniSuccess : Color.euniSecondary)
                                .font(.title2)
                            
                            if iapManager.hasFullAccess {
                                Text("Full Access - Lifetime Purchase")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.euniText)
                            } else if let activeSubscription = getCurrentSubscription() {
                                Text("Subscribed to \(activeSubscription)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.euniText)
                            } else {
                                Text("No Active Subscription")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.euniText)
                            }
                        }
                        
                        // Show remaining time for subscription or trial
                        if iapManager.hasActiveSubscription, let timeRemaining = iapManager.timeRemainingInTrial() {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(Color.euniSecondary)
                                Text("\(timeRemaining)")
                                    .foregroundColor(Color.euniSecondary)
                                    .font(.title3)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                // Purchase Options
                GroupBox {
                    if !iapManager.hasFullAccess {
                        VStack(spacing: 20) {
                            Text("Select a purchase option")
                                .font(.headline)
                                .foregroundColor(Color.euniText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Subscription options
                            VStack(spacing: 16) {
                                // Full Unlock Button (One-Time Purchase)
                                if let fullUnlockProduct = iapManager.getProduct(for: .fullUnlock) {
                                    SubscriptionButton(
                                        title: IAPProduct.fullUnlock.displayName,
                                        description: IAPProduct.fullUnlock.description,
                                        price: fullUnlockProduct.displayPrice,
                                        isPermanent: true,
                                        action: {
                                            Task {
                                                await iapManager.purchase(fullUnlockProduct)
                                            }
                                        }
                                    )
                                }
                                
                                // Get current subscription tier
                                let currentTier = getCurrentSubscriptionTier()
                                
                                // Yearly Plan
                                if let yearlyPlan = iapManager.getProduct(for: .yearlySubscription) {
                                    let isCurrentSubscription = currentTier == .yearly
                                    SubscriptionButton(
                                        title: getSubscriptionTitle(.yearlySubscription, currentTier: currentTier),
                                        description: getSubscriptionDescription(.yearlySubscription, currentTier: currentTier, price: yearlyPlan.displayPrice),
                                        price: yearlyPlan.displayPrice,
                                        isBestValue: true,
                                        isCurrentPlan: isCurrentSubscription,
                                        action: {
                                            Task {
                                                if !isCurrentSubscription {
                                                    await iapManager.purchase(yearlyPlan)
                                                }
                                            }
                                        }
                                    )
                                }
                                
                                // Quarterly Plan
                                if let quarterlyPlan = iapManager.getProduct(for: .threeMonthSubscription) {
                                    let isCurrentSubscription = currentTier == .quarterly
                                    SubscriptionButton(
                                        title: getSubscriptionTitle(.threeMonthSubscription, currentTier: currentTier),
                                        description: getSubscriptionDescription(.threeMonthSubscription, currentTier: currentTier, price: quarterlyPlan.displayPrice),
                                        price: quarterlyPlan.displayPrice,
                                        isCurrentPlan: isCurrentSubscription,
                                        action: {
                                            Task {
                                                if !isCurrentSubscription {
                                                    await iapManager.purchase(quarterlyPlan)
                                                }
                                            }
                                        }
                                    )
                                }
                                
                                // Monthly Plan
                                if let monthlyPlan = iapManager.getProduct(for: .oneMonthSubscription) {
                                    let isCurrentSubscription = currentTier == .monthly
                                    SubscriptionButton(
                                        title: getSubscriptionTitle(.oneMonthSubscription, currentTier: currentTier),
                                        description: getSubscriptionDescription(.oneMonthSubscription, currentTier: currentTier, price: monthlyPlan.displayPrice),
                                        price: monthlyPlan.displayPrice,
                                        isCurrentPlan: isCurrentSubscription,
                                        action: {
                                            Task {
                                                if !isCurrentSubscription {
                                                    await iapManager.purchase(monthlyPlan)
                                                }
                                            }
                                        }
                                    )
                                }
                                
                                // Weekly Plan
                                if let weeklyPlan = iapManager.getProduct(for: .oneWeekSubscription) {
                                    let isCurrentSubscription = currentTier == .weekly
                                    SubscriptionButton(
                                        title: getSubscriptionTitle(.oneWeekSubscription, currentTier: currentTier),
                                        description: getSubscriptionDescription(.oneWeekSubscription, currentTier: currentTier, price: weeklyPlan.displayPrice),
                                        price: weeklyPlan.displayPrice,
                                        isCurrentPlan: isCurrentSubscription,
                                        action: {
                                            Task {
                                                if !isCurrentSubscription {
                                                    await iapManager.purchase(weeklyPlan)
                                                }
                                            }
                                        }
                                    )
                                }
                                
                                Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Cancel anytime in your AppStore account settings.")
                                    .font(.caption)
                                    .foregroundColor(Color.euniSecondary)
                                    .padding(.top, 8)
                            }
                            
                            /*
                            #if DEBUG
                            Divider()
                                .padding(.vertical)
                            
                            Text("Debug Options (Development Only)")
                                .font(.headline)
                                .foregroundColor(Color.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Full Unlock (One-Time Purchase)
                            Button(action: {
                                Task {
                                    await iapManager.simulatePurchase(for: .fullUnlock)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                    Text("Simulate One-Time Purchase")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            // Yearly Subscription
                            Button(action: {
                                Task {
                                    await iapManager.simulatePurchase(for: .yearlySubscription)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                    Text("Simulate 1-Year Subscription")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            // Quarterly Subscription
                            Button(action: {
                                Task {
                                    await iapManager.simulatePurchase(for: .threeMonthSubscription)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                    Text("Simulate 3-Month Subscription")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            // Monthly Subscription
                            Button(action: {
                                Task {
                                    await iapManager.simulatePurchase(for: .oneMonthSubscription)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                    Text("Simulate 1-Month Subscription")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            // Weekly Subscription
                            Button(action: {
                                Task {
                                    await iapManager.simulatePurchase(for: .oneWeekSubscription)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                    Text("Simulate 1-Week Subscription")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                Task {
                                    await iapManager.resetPurchases()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset All Purchases")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                            }
                            #endif
                            */
                        }
                        .padding()
                    } else {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.euniSuccess)
                                .font(.title2)
                            Text("You have full access to all features")
                                .font(.title3)
                                .foregroundColor(Color.euniText)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                
                // What's included section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What's included:")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.euniText)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureItem(title: "Unlimited AI therapy note generation")
                            FeatureItem(title: "Easy Note templates for quick documentation")
                            FeatureItem(title: "Access to all Ollama models")
                            FeatureItem(title: "Automatic safety documentation tools")
                            FeatureItem(title: "Regular app updates with new features")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                // Restore Purchases
                GroupBox {
                    Button(action: {
                        Task {
                            await iapManager.restorePurchases()
                            showingRestoreAlert = true
                            if iapManager.hasFullAccess {
                                restoreMessage = "Your purchases have been successfully restored!"
                                showingRestoreSuccess = true
                            } else {
                                restoreMessage = "No purchases found to restore."
                                showingRestoreSuccess = false
                            }
                        }
                    }) {
                        HStack {
                            Text("Restore Purchases")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.clockwise")
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(iapManager.isLoading)
                    
                    Text("If you previously purchased full access, use this button to restore your purchases on this device.")
                        .font(.caption)
                        .foregroundColor(Color.euniSecondary)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .frame(minWidth: 600, idealWidth: 700, maxWidth: .infinity, minHeight: 700, idealHeight: 800, maxHeight: .infinity)
        .alert(isPresented: $showingRestoreAlert) {
            Alert(
                title: Text(showingRestoreSuccess ? "Success" : "Restore Complete"),
                message: Text(restoreMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            iapManager.isLoading ?
                ProgressView("Processing...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.euniBackground))
                    .shadow(radius: 10)
                : nil
        )
        .onChange(of: iapManager.errorMessage) { _, newValue in
            showingErrorAlert = newValue != nil
        }
        .navigationTitle("Subscription")
        .background(Color.euniBackground)
        .onAppear {
            // Force refresh products when view appears
            Task {
                await iapManager.loadProducts()
            }
        }
    }
    
    // Helper methods for subscription status
    enum SubscriptionTier {
        case none, weekly, monthly, quarterly, yearly
    }
    
    func getCurrentSubscriptionTier() -> SubscriptionTier {
        if iapManager.purchasedProductIDs.contains(IAPProduct.yearlySubscription.rawValue) {
            return .yearly
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.threeMonthSubscription.rawValue) {
            return .quarterly
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.oneMonthSubscription.rawValue) {
            return .monthly
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.oneWeekSubscription.rawValue) {
            return .weekly
        } else {
            return .none
        }
    }
    
    func getCurrentSubscription() -> String? {
        if iapManager.purchasedProductIDs.contains(IAPProduct.yearlySubscription.rawValue) {
            return "1-Year Plan"
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.threeMonthSubscription.rawValue) {
            return "3-Month Plan"
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.oneMonthSubscription.rawValue) {
            return "1-Month Plan"
        } else if iapManager.purchasedProductIDs.contains(IAPProduct.oneWeekSubscription.rawValue) {
            return "1-Week Plan"
        } else {
            return nil
        }
    }
    
    func getSubscriptionTitle(_ product: IAPProduct, currentTier: SubscriptionTier) -> String {
        if isTierHigher(product: product, than: currentTier) {
            return "Upgrade to \(product.displayName)"
        } else if isTierLower(product: product, than: currentTier) {
            return "Downgrade to \(product.displayName)"
        } else if getTierFromProduct(product) == currentTier {
            return "Current Plan: \(product.displayName)"
        } else {
            return product.displayName
        }
    }
    
    func getSubscriptionDescription(_ product: IAPProduct, currentTier: SubscriptionTier, price: String) -> String {
        if getTierFromProduct(product) == currentTier {
            return "Your current subscription"
        } else {
            switch product {
            case .oneWeekSubscription:
                return "Free trial of 3 days, then \(price)/week"
            case .oneMonthSubscription:
                return "Free trial of 7 days, then \(price)/month"
            case .threeMonthSubscription:
                return "Free trial of 7 days, then \(price)/3 months"
            case .yearlySubscription:
                return "Free trial of 7 days, then \(price)/year"
            default:
                return product.description
            }
        }
    }
    
    func getTierFromProduct(_ product: IAPProduct) -> SubscriptionTier {
        switch product {
        case .yearlySubscription:
            return .yearly
        case .threeMonthSubscription:
            return .quarterly
        case .oneMonthSubscription:
            return .monthly
        case .oneWeekSubscription:
            return .weekly
        default:
            return .none
        }
    }
    
    func isTierHigher(product: IAPProduct, than currentTier: SubscriptionTier) -> Bool {
        let productTier = getTierFromProduct(product)
        switch (productTier, currentTier) {
        case (.yearly, .monthly), (.yearly, .quarterly), (.yearly, .weekly),
             (.quarterly, .monthly), (.quarterly, .weekly),
             (.monthly, .weekly):
            return true
        default:
            return false
        }
    }
    
    func isTierLower(product: IAPProduct, than currentTier: SubscriptionTier) -> Bool {
        let productTier = getTierFromProduct(product)
        switch (productTier, currentTier) {
        case (.weekly, .monthly), (.weekly, .quarterly), (.weekly, .yearly),
             (.monthly, .quarterly), (.monthly, .yearly),
             (.quarterly, .yearly):
            return true
        default:
            return false
        }
    }
}

struct SubscriptionButton: View {
    let title: String
    let description: String
    let price: String
    var isBestValue: Bool = false
    var isPermanent: Bool = false
    var isCurrentPlan: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button {
            // Call the action directly here
            if !isCurrentPlan {
                action()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.euniText)
                        
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                        
                        if isPermanent {
                            Text("PERMANENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                        
                        if isCurrentPlan {
                            Text("CURRENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(Color.euniSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(price)
                    .font(.headline)
                    .foregroundColor(Color.euniPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.euniPrimary, lineWidth: 2)
                    )
            }
            .padding(16)
            .background(isCurrentPlan ? Color.blue.opacity(0.1) : Color.euniFieldBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isPermanent ? Color.purple.opacity(0.5) :
                            isCurrentPlan ? Color.blue.opacity(0.7) :
                                (isBestValue ? Color.green.opacity(0.5) : Color.euniBorder),
                        lineWidth: isCurrentPlan ? 2 : 1
                    )
            )
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle())
        .opacity(isCurrentPlan ? 0.8 : 1.0)
    }
}

struct FeatureItem: View {
    let title: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.euniSuccess)
                .font(.body)
            
            Text(title)
                .font(.body)
                .foregroundColor(Color.euniText)
        }
    }
}

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PurchaseView()
        }
    }
} 