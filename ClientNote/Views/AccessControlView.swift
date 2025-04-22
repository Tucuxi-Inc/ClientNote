import SwiftUI
import StoreKit

public struct AccessControlView<Content: View>: View {
    // Restore IAPManager
    @StateObject private var iapManager: IAPManager = .shared
    @State private var showPurchaseView = false
    let content: Content
    
    /*
    #if DEBUG
    // For development, allows bypassing access control
    @AppStorage("bypassAccessControl") private var bypassAccessControl = false
    #endif
    */
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        // Restore original implementation (except the PurchaseView)
        Group {
            /*
            #if DEBUG
            if bypassAccessControl || iapManager.hasAccess() {
                content
                    .overlay(alignment: .topTrailing) {
                        if bypassAccessControl {
                            Button {
                                bypassAccessControl = false
                            } label: {
                                HStack(spacing: 4) {
                                    Text("BYPASSING ACCESS CONTROL")
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .font(.caption)
                                .padding(6)
                                .background(Color.orange.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(8)
                        }
                    }
            } else {
                // No access - show purchase/trial view
                TrialExpiredView {
                    showPurchaseView = true
                }
                .overlay(alignment: .topTrailing) {
                    Button("DEV: Bypass Access Control") {
                        bypassAccessControl = true
                    }
                    .padding(8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                    .padding()
                }
            }
            #else
            */
            if iapManager.hasAccess() {
                content
            } else {
                // No access - show purchase/trial view
                TrialExpiredView {
                    showPurchaseView = true
                }
            }
            /*
            #endif
            */
        }
        .sheet(isPresented: $showPurchaseView) {
            NavigationView {
                // Restore PurchaseView
                PurchaseView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showPurchaseView = false
                            }
                        }
                    }
            }
        }
    }
}

struct TrialExpiredView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image("1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                
                Text("Euni™ - Easy Therapy Notes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Text("Your trial has expired")
                    .font(.title3)
                    .foregroundColor(Color.euniSecondary)
            }
            .padding(.bottom, 16)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureItemLarge(title: "Unlimited AI therapy note generation")
                FeatureItemLarge(title: "Easy Note templates for documentation")
                FeatureItemLarge(title: "Access to all Ollama models")
                FeatureItemLarge(title: "Safety documentation tools")
                FeatureItemLarge(title: "Regular app updates")
            }
            .padding(.bottom, 20)
            
            Button(action: action) {
                Text("View Purchase Options")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(Color.euniPrimary)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Unlock all features with a one-time purchase")
                .font(.caption)
                .foregroundColor(Color.euniSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
    }
}

struct FeatureItemLarge: View {
    let title: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.euniSuccess)
                .font(.subheadline)
            
            Text(title)
                .font(.body)
                .foregroundColor(Color.euniText)
        }
    }
}

struct AccessControlView_Previews: PreviewProvider {
    static var previews: some View {
        AccessControlView {
            Text("Content that requires purchase")
        }
    }
} 