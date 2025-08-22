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
            
        }
    }
}
