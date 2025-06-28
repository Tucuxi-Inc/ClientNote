import SwiftUI
import SwiftData
import Defaults
import OllamaKit

struct SplashScreen: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Binding var isPresented: Bool
    @State private var showingFirstTimeSetup = false
    @State private var isCheckingSetup = true
    
    private let logoImage = "1_Eunitm-Client-Notes-Effortless-AI-Powered-Therapy-Documentation"
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            Color.euniBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 800, maxHeight: 800)
                
                if isCheckingSetup {
                    ProgressView("Loading...")
                        .progressViewStyle(.circular)
                }
            }
            .padding()
        }
        .onAppear {
            checkFirstTimeSetup()
        }
        .sheet(isPresented: $showingFirstTimeSetup) {
            FirstTimeSetupView(isPresented: $showingFirstTimeSetup)
                .interactiveDismissDisabled()
                .onDisappear {
                    dismissSplashScreen()
                }
        }
    }
    
    private func checkFirstTimeSetup() {
        isCheckingSetup = true
        
        Task {
            await MainActor.run {
                isCheckingSetup = false
                
                // Check if this is first launch
                if !Defaults[.defaultHasLaunched] {
                    showingFirstTimeSetup = true
                } else {
                    // Not first launch, dismiss splash screen
                    dismissSplashScreen()
                }
            }
        }
    }
    
    private func dismissSplashScreen() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

#Preview {
    SplashScreen(isPresented: .constant(true))
}

 