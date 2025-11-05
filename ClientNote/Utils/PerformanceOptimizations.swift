//
//  PerformanceOptimizations.swift
//  ClientNote
//
//  Created by AI Assistant
//  Performance optimization utilities for better app responsiveness
//

import SwiftUI

// MARK: - Lazy View

/// A view that delays its content creation until it's actually needed
/// Useful for complex views in NavigationLinks or Lists
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}

// MARK: - Cached Async Image

/// An async image loader with caching support
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func get(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Debouncer

/// Debounces rapid function calls, useful for search fields
class Debouncer: ObservableObject {
    private var workItem: DispatchWorkItem?
    private let delay: TimeInterval

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let newWorkItem = DispatchWorkItem(block: action)
        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }

    func cancel() {
        workItem?.cancel()
    }
}

// MARK: - View Extensions

extension View {
    /// Wrap view in LazyView for deferred loading
    func lazy() -> some View {
        LazyView(self)
    }

    /// Add task with debouncing for expensive operations
    func debouncedTask(
        id: some Equatable,
        delay: TimeInterval = 0.3,
        priority: TaskPriority = .userInitiated,
        action: @escaping () async -> Void
    ) -> some View {
        self.task(id: id, priority: priority) {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await action()
        }
    }
}

// MARK: - List Performance Helper

/// Helper to improve list scrolling performance
struct OptimizedList<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    let data: Data
    let rowContent: (Data.Element) -> RowContent

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(data), id: \.id) { item in
                    rowContent(item)
                        .id(item.id)
                }
            }
        }
    }
}

// MARK: - Expensive Computation Cache

/// Cache for expensive computations
actor ComputationCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(for key: Key) -> Value? {
        cache[key]
    }

    func set(_ value: Value, for key: Key) {
        if cache.count >= maxSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[key] = value
    }

    func clear() {
        cache.removeAll()
    }
}

// MARK: - Throttler

/// Throttles function calls to a maximum rate
class Throttler {
    private var lastExecutionTime: Date?
    private let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval = 0.1) {
        self.minimumInterval = minimumInterval
    }

    func throttle(action: @escaping () -> Void) {
        let now = Date()

        if let lastTime = lastExecutionTime,
           now.timeIntervalSince(lastTime) < minimumInterval {
            return
        }

        lastExecutionTime = now
        action()
    }
}

// MARK: - Memory Warning Handler

/// Observes and handles memory warnings
class MemoryWarningHandler: ObservableObject {
    @Published var didReceiveMemoryWarning = false

    init() {
        // Note: Memory warnings are primarily for iOS
        // macOS apps should monitor memory usage differently
    }

    func clearCaches() {
        ImageCache.shared.clear()
        // Add other cache clearing operations here
    }
}

// MARK: - View Modifiers

struct OnVisibleModifier: ViewModifier {
    let action: () -> Void
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    action()
                }
            }
    }
}

extension View {
    /// Perform action only on first appearance
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(OnVisibleModifier(action: action))
    }
}

// MARK: - Usage Examples in Comments

/*
 Usage Examples:

 1. Lazy View:
    NavigationLink(destination: LazyView(ExpensiveView())) {
        Text("Open")
    }

 2. Debounced Search:
    @StateObject private var debouncer = Debouncer(delay: 0.5)

    TextField("Search", text: $searchText)
        .onChange(of: searchText) { newValue in
            debouncer.debounce {
                performSearch(query: newValue)
            }
        }

 3. Optimized List:
    OptimizedList(data: items) { item in
        ItemRow(item: item)
    }

 4. Throttled Updates:
    private let throttler = Throttler(minimumInterval: 0.1)

    func onScroll() {
        throttler.throttle {
            updateVisibleItems()
        }
    }
 */
