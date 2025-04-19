import SwiftUI
import Defaults

@Observable
class SplashScreenManager {
    var isShowingSplash = true
    
    func dismissSplash() {
        withAnimation(.easeOut(duration: 0.3)) {
            isShowingSplash = false
        }
    }
    
    // Call this when the app is ready to show the main content
    func appIsReady() {
        // Add a small delay to ensure the splash screen has time to display
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismissSplash()
        }
    }
} 