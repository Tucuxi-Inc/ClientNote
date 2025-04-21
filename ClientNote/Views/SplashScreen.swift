import SwiftUI
import Defaults

struct SplashScreen: View {
    @State private var currentImageIndex = 0
    @State private var opacity = 1.0
    @State private var scale = 1.0
    @State private var isFirstLaunch = !Defaults[.hasLaunchedBefore]
    
    // First launch images
    private let firstLaunchImages = [
        "splash1",
        "splash2",
        "splash3",
        "splash4"
    ]
    
    // Regular launch image
    private let regularLaunchImage = "splash_logo"
    
    // Animation timing
    private let imageTransitionDuration: Double = 0.5
    private let imageDisplayDuration: Double = 2.0
    private let finalDisplayDuration: Double = 1.5
    
    var body: some View {
        ZStack {
            Color.euniBackground
                .ignoresSafeArea()
            
            if isFirstLaunch {
                // First launch experience with multiple images
                if let _ = UIImage(named: firstLaunchImages[currentImageIndex]) {
                    // Use actual image if available
                    Image(firstLaunchImages[currentImageIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400, height: 400)
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .onAppear {
                            animateFirstLaunch()
                        }
                } else {
                    // Use placeholder if image not found
                    PlaceholderImageGenerator.generatePlaceholderImage(name: firstLaunchImages[currentImageIndex])
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .onAppear {
                            animateFirstLaunch()
                        }
                }
            } else {
                // Regular launch with single image
                if let _ = UIImage(named: regularLaunchImage) {
                    // Use actual image if available
                    Image(regularLaunchImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .onAppear {
                            animateRegularLaunch()
                        }
                } else {
                    // Use placeholder if image not found
                    PlaceholderImageGenerator.generatePlaceholderImage(name: regularLaunchImage, size: CGSize(width: 300, height: 300))
                        .opacity(opacity)
                        .scaleEffect(scale)
                        .onAppear {
                            animateRegularLaunch()
                        }
                }
            }
        }
    }
    
    private func animateFirstLaunch() {
        // Start with a fade-in and scale-up animation
        withAnimation(.easeIn(duration: imageTransitionDuration)) {
            opacity = 1.0
            scale = 1.0
        }
        
        // After displaying the current image, transition to the next one
        DispatchQueue.main.asyncAfter(deadline: .now() + imageDisplayDuration) {
            // Fade out current image
            withAnimation(.easeOut(duration: imageTransitionDuration)) {
                opacity = 0.0
                scale = 0.8
            }
            
            // After fade out, change to next image
            DispatchQueue.main.asyncAfter(deadline: .now() + imageTransitionDuration) {
                if currentImageIndex < firstLaunchImages.count - 1 {
                    // Move to next image
                    currentImageIndex += 1
                    
                    // Fade in new image
                    withAnimation(.easeIn(duration: imageTransitionDuration)) {
                        opacity = 1.0
                        scale = 1.0
                    }
                    
                    // Continue the cycle
                    DispatchQueue.main.asyncAfter(deadline: .now() + imageDisplayDuration) {
                        animateFirstLaunch()
                    }
                } else {
                    // We've shown all images, mark as launched
                    Defaults[.hasLaunchedBefore] = true
                    
                    // Fade in the final image
                    withAnimation(.easeIn(duration: imageTransitionDuration)) {
                        opacity = 1.0
                        scale = 1.0
                    }
                    
                    // Dismiss after final display
                    DispatchQueue.main.asyncAfter(deadline: .now() + finalDisplayDuration) {
                        withAnimation(.easeOut(duration: imageTransitionDuration)) {
                            opacity = 0.0
                            scale = 0.8
                        }
                    }
                }
            }
        }
    }
    
    private func animateRegularLaunch() {
        // Start with a fade-in and scale-up animation
        withAnimation(.easeIn(duration: imageTransitionDuration)) {
            opacity = 1.0
            scale = 1.0
        }
        
        // Dismiss after display duration
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDisplayDuration) {
            withAnimation(.easeOut(duration: imageTransitionDuration)) {
                opacity = 0.0
                scale = 0.8
            }
        }
    }
}

// Extension to Defaults for tracking first launch
extension DefaultsKey {
    static let hasLaunchedBefore = Key<Bool>("hasLaunchedBefore", default: false)
}

#Preview {
    SplashScreen()
} 