import Defaults
import SwiftUI

struct GeneralView: View {
    @Default(.defaultHost) private var defaultHost
    @Default(.defaultSystemPrompt) private var defaultSystemPrompt
    
    @State private var isUpdateOllamaHostPresented = false
    @State private var isUpdateSystemPromptPresented = false
    
    var body: some View {
        Form {
            Section {
                Box {
                    Text("Default Ollama Host")
                        .font(.headline.weight(.semibold))
                    
                    HStack {
                        Text(defaultHost)
                            .help(defaultHost)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateOllamaHostPresented = true })
                            .foregroundColor(Color.euniPrimary)
                    }
                }
            } footer: {
                SectionFooter("This host will be used for new chats.")
                    .padding(.bottom)
                    .foregroundColor(Color.euniSecondary)
            }
            
            Section {
                Box {
                    Text("Default System Prompt")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color.euniText)
                    
                    HStack {
                        Text(defaultSystemPrompt)
                            .help(defaultSystemPrompt)
                            .lineLimit(1)
                            .foregroundColor(Color.euniSecondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateSystemPromptPresented = true })
                            .foregroundColor(Color.euniPrimary)
                    }
                }
            } footer: {
                SectionFooter("This prompt will be used for new chats.")
                    .foregroundColor(Color.euniSecondary)
            }

            Section {
                Box {
                    DefaultFontSizeField()
                }
            }
        }
        .sheet(isPresented: $isUpdateOllamaHostPresented) {
            UpdateOllamaHostSheet(host: defaultHost) { host in
                self.defaultHost = host
            }
        }
        .sheet(isPresented: $isUpdateSystemPromptPresented) {
            UpdateSystemPromptSheet(prompt: defaultSystemPrompt) { prompt in
                self.defaultSystemPrompt = prompt
            }
        }
    }
}

#Preview("General Settings") {
    GeneralView()
        .frame(width: 512)
        .padding()
}
