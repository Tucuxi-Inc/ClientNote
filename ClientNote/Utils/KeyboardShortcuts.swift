//
//  KeyboardShortcuts.swift
//  ClientNote
//
//  Created by AI Assistant
//  Centralized keyboard shortcuts for the application
//

import SwiftUI

/// Keyboard shortcut definitions for common actions
struct KeyboardShortcuts {
    // MARK: - Navigation
    static let newActivity = KeyEquivalent("n")
    static let search = KeyEquivalent("k")
    static let settings = KeyEquivalent(",")
    static let closeWindow = KeyEquivalent("w")

    // MARK: - Editing
    static let regenerate = KeyEquivalent("r")
    static let copy = KeyEquivalent("c")
    static let delete = KeyEquivalent(.delete)

    // MARK: - Activity Management
    static let nextActivity = KeyEquivalent("]")
    static let previousActivity = KeyEquivalent("[")

    // MARK: - Modifiers
    static let commandModifier: EventModifiers = [.command]
    static let commandShiftModifier: EventModifiers = [.command, .shift]
    static let commandOptionModifier: EventModifiers = [.command, .option]
}

// MARK: - View Extensions for Shortcuts

extension View {
    /// Add new activity keyboard shortcut (Cmd+N)
    func keyboardShortcutNewActivity(action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(KeyboardShortcuts.newActivity, modifiers: KeyboardShortcuts.commandModifier)
    }

    /// Add search keyboard shortcut (Cmd+K)
    func keyboardShortcutSearch(action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(KeyboardShortcuts.search, modifiers: KeyboardShortcuts.commandModifier)
    }

    /// Add settings keyboard shortcut (Cmd+,)
    func keyboardShortcutSettings(action: @escaping () -> Void) -> some View {
        self.keyboardShortcut(KeyboardShortcuts.settings, modifiers: KeyboardShortcuts.commandModifier)
    }
}
