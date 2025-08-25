import SwiftUI

struct CustomTooltip: View {
    let text: String
    let delay: TimeInterval
    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?
    
    init(_ text: String, delay: TimeInterval = 0.5) {
        self.text = text
        self.delay = delay
    }
    
    var body: some View {
        ZStack {
            if showTooltip {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .offset(y: -30)
                    .zIndex(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)).animation(.easeOut(duration: 0.15)))
            }
        }
        .onHover { hovering in
            if hovering {
                startHoverTimer()
            } else {
                cancelHoverTimer()
                hideTooltip()
            }
        }
    }
    
    private func startHoverTimer() {
        hoverTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showTooltip = true
                    }
                }
            }
        }
    }
    
    private func cancelHoverTimer() {
        hoverTask?.cancel()
        hoverTask = nil
    }
    
    private func hideTooltip() {
        withAnimation(.easeIn(duration: 0.1)) {
            showTooltip = false
        }
    }
}

extension View {
    func customTooltip(_ text: String, delay: TimeInterval = 0.5) -> some View {
        overlay(CustomTooltip(text, delay: delay))
    }
}