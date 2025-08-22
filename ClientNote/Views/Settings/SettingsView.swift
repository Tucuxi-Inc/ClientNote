import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            TabView {
                GeneralView()
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
            }
        }
        .padding()
        .frame(width: 580)
        .background(Color.euniBackground)
        .foregroundColor(Color.euniText)
    }
}
