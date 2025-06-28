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
    @State private var showingServiceOptions = false
    
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
                
                Text("Choose Your AI Service")
                    .font(.title3)
                    .foregroundColor(Color.euniSecondary)
            }
            .padding(.bottom, 16)
            
            // Service Options
            VStack(spacing: 16) {
                // Subscription/One-Time Purchase Option
                Button(action: action) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use with a Subscription or One-Time Purchase")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Uses Cloud Based AI")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "star.fill")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.euniPrimary)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Use Own API Key Option
                Button(action: {
                    showingServiceOptions = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use with your own OpenAI API Key")
                                .font(.headline)
                                .foregroundColor(Color.euniText)
                            Text("Uses Cloud Based AI at public API costs that you pay the AI provider")
                                .font(.caption)
                                .foregroundColor(Color.euniSecondary)
                        }
                        Spacer()
                        Image(systemName: "key.fill")
                            .foregroundColor(Color.euniPrimary)
                    }
                    .padding()
                    .background(Color.euniFieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.euniBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Ollama Option
                Button(action: {
                    showingServiceOptions = true
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use with Ollama")
                                .font(.headline)
                                .foregroundColor(Color.euniText)
                            Text("Free - Processes client data only on Your Computer")
                                .font(.caption)
                                .foregroundColor(Color.euniSecondary)
                        }
                        Spacer()
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(Color.euniPrimary)
                    }
                    .padding()
                    .background(Color.euniFieldBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.euniBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("You can change your selection anytime in Settings")
                .font(.caption)
                .foregroundColor(Color.euniSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
        .sheet(isPresented: $showingServiceOptions) {
            NavigationView {
                AIServiceSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingServiceOptions = false
                            }
                        }
                    }
            }
        }
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