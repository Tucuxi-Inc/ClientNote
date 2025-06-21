import SwiftUI
import AppKit

struct PlaceholderImageGenerator {
    @MainActor
    static func generatePlaceholderImage(name: String, size: CGSize = CGSize(width: 400, height: 400)) -> Image {
        let content = ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.euniPrimary.opacity(0.2))
            
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.euniPrimary)
                
                Text(name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.euniText)
                
                Text("Replace with your actual image")
                    .font(.caption)
                    .foregroundColor(Color.euniSecondary)
            }
            .padding()
        }
        .frame(width: size.width, height: size.height)
        
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        
        if let nsImage = renderer.nsImage {
            return Image(nsImage: nsImage)
        } else {
            // Fallback to a simple colored rectangle if rendering fails
            return Image(systemName: "photo")
        }
    }
} 