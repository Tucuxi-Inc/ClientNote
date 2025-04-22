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
            
            /*
            #if DEBUG
            Section {
                Box {
                    HStack(alignment: .center) {
                        Text("Bypass Purchase Controls")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.orange)
                        
                        Spacer()
                        
                        Toggle("", isOn: $bypassAccessControl)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color.orange)
                    }
                }
            } footer: {
                SectionFooter("DEVELOPMENT ONLY: Bypass all in-app purchase restrictions.")
                    .foregroundColor(Color.orange)
            }
            #endif
            */
        }
    }
}
