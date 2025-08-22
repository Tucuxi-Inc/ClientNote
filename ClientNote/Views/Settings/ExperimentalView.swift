import Defaults
import SwiftUI

struct ExperimentalView: View {
    @Default(.experimentalCodeHighlighting) private var experimentalCodeHighlighting
    
    /*
    #if DEBUG
    @AppStorage("bypassAccessControl") private var bypassAccessControl = false
    #endif
    */
    
    var body: some View {
        Form {
            Section {
                Box {
                    HStack(alignment: .center) {
                        Text("Code Highlighting")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.euniText)
                        
                        Spacer()
                        
                        Toggle("", isOn: $experimentalCodeHighlighting)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color.euniPrimary)
                    }
                }
            } footer: {
                SectionFooter("Enabling this might affect generation and scrolling performance.")
                    .foregroundColor(Color.euniSecondary)
            }
            
            #if DEBUG
            Section {
                Box {
                    Button(action: {
                        // No purchases to reset in free version
                        print("DEBUG: No purchases to reset in free version")
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset All Purchases")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                SectionFooter("DEVELOPMENT ONLY: Resets all StoreKit test purchases.")
                    .foregroundColor(Color.orange)
            }
            #endif
        }
    }
}
