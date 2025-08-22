//
//  TermsAndPrivacyView.swift
//  ClientNote
//
//  First-time Terms of Use and Privacy Policy agreement view
//

import SwiftUI
import Defaults

struct TermsAndPrivacyView: View {
    let onAgreementAccepted: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Welcome message
            VStack(spacing: 16) {
                Text("Welcome to Euni - Client Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Text("Thank you for choosing Euni Client Notes for your therapy practice. Before you begin, please review and accept our terms and policies.")
                    .font(.body)
                    .foregroundColor(Color.euniSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Agreement section
            VStack(spacing: 20) {
                HStack(spacing: 4) {
                    Text("By clicking Agree and Continue, you agree to our ")
                        .font(.body)
                        .foregroundColor(Color.euniSecondary)
                    
                    Button("Terms of Use") {
                        openTermsOfUse()
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(" and ")
                        .font(.body)
                        .foregroundColor(Color.euniSecondary)
                    
                    Button("Privacy Policy") {
                        openPrivacyPolicy()
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
                .multilineTextAlignment(.center)
                
                Button(action: {
                    acceptTermsAndContinue()
                }) {
                    Text("Agree and Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.euniPrimary)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.euniBackground)
    }
    
    private func openTermsOfUse() {
        if let pdfURL = Bundle.main.url(forResource: "Tucuxi_Terms_of_Use", withExtension: "pdf") {
            NSWorkspace.shared.open(pdfURL)
        } else {
            print("Error: Tucuxi_Terms_of_Use.pdf not found in bundle")
        }
    }
    
    private func openPrivacyPolicy() {
        if let pdfURL = Bundle.main.url(forResource: "privacy_policy", withExtension: "pdf") {
            NSWorkspace.shared.open(pdfURL)
        } else {
            print("Error: privacy_policy.pdf not found in bundle")
        }
    }
    
    private func acceptTermsAndContinue() {
        // Set the flag that user has accepted terms
        Defaults[.hasAcceptedTermsAndPrivacy] = true
        
        // Call the completion handler
        onAgreementAccepted()
    }
}

#Preview {
    TermsAndPrivacyView {
        print("Terms accepted")
    }
}