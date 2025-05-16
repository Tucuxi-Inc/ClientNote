import SwiftUI
import StoreKit  // For IAPManager and StoreKit functionality

struct SettingsView: View {
    // Uncomment the IAPManager to restore functionality
    @StateObject private var iapManager = IAPManager.shared
    
    var body: some View {
        VStack {
            TabView {
                GeneralView()
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                
                // Restore the PurchaseView
                PurchaseView()
                    .tabItem {
                        Label("Subscription", systemImage: "creditcard")
                    }
                    .badge(iapManager.hasFullAccess ? nil : "!")
                
                ExperimentalView()
                    .tabItem {
                        Label("Experimental", systemImage: "testtube.2")
                    }
            }
        }
        .padding()
        .frame(width: 580)
        .background(Color.euniBackground)
        .foregroundColor(Color.euniText)
    }
}
