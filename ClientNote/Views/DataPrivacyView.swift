//
//  DataPrivacyView.swift
//  ClientNote
//
//  Data privacy information view
//

import SwiftUI

struct DataPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Data Privacy")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider()
                
                // Privacy information
                Text("When you operate Euni ClientNote in OpenAI mode the application uses a cloud based model from OpenAI to generate your notes. Audio recordings remain on your device, but all other information necessary to generate the note (including client identifier, treatments plans, past client notes and the text transcribed from your session recordings or that you dictate and use to populate your prompts to the application will be sent to OpenAI for processing prompts and generating treatment plans, notes, etc. Data will be processed, retained and shared pursuant to your agreement with OpenAI. Please review your data privacy settings associated with the developer API key you use for this mode to ensure it meets your privacy and security needs.  OpenAI inference can be faster, but your data will go to them. Be aware of the tradeoffs and use this application appropriately and within the guidelines, rules and laws applicable to your use and processing of the data. Whether in Free or OpenAI mode, Tucuxi, Inc. does not receive any data from or about you, but in OpenAI mode OpenAI will.")
                    .font(.body)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(30)
        }
        .frame(width: 600, height: 400)
        .background(Color.euniBackground)
        .foregroundColor(Color.euniText)
    }
}

#Preview {
    DataPrivacyView()
}