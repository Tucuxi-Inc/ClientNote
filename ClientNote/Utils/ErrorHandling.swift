//
//  ErrorHandling.swift
//  ClientNote
//
//  Created by AI Assistant
//  Centralized error handling system with user-friendly messages
//

import SwiftUI

// MARK: - App Errors

/// Centralized error types for the application
enum AppError: LocalizedError, Identifiable {
    case networkError(String)
    case aiServiceError(String)
    case fileOperationError(String)
    case permissionDenied(String)
    case validationError(String)
    case unknownError(String)

    var id: String {
        errorDescription ?? "unknown"
    }

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .aiServiceError(let message):
            return "AI Service Error: \(message)"
        case .fileOperationError(let message):
            return "File Operation Error: \(message)"
        case .permissionDenied(let message):
            return "Permission Denied: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        case .unknownError(let message):
            return "Error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .aiServiceError:
            return "Please check your AI service settings and ensure the service is running."
        case .fileOperationError:
            return "Please check file permissions and available disk space."
        case .permissionDenied:
            return "Please grant the necessary permissions in System Preferences."
        case .validationError:
            return "Please check your input and try again."
        case .unknownError:
            return "Please try again or contact support if the problem persists."
        }
    }

    var icon: String {
        switch self {
        case .networkError:
            return "wifi.exclamationmark"
        case .aiServiceError:
            return "brain.head.profile"
        case .fileOperationError:
            return "doc.badge.exclamationmark"
        case .permissionDenied:
            return "lock.shield"
        case .validationError:
            return "exclamationmark.triangle"
        case .unknownError:
            return "exclamationmark.circle"
        }
    }
}

// MARK: - Error Banner View

/// A banner view for displaying errors with retry action
struct ErrorBanner: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    init(error: AppError, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: .spacingM) {
            Image(systemName: error.icon)
                .font(.title3)
                .foregroundColor(Color.euniError)

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(error.errorDescription ?? "Unknown Error")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.euniText)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: .spacingS) {
                if let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.euniSecondary)
                    .controlSize(.small)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.spacingM)
        .background(Color.euniError.opacity(0.1))
        .cornerRadius(.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusM)
                .stroke(Color.euniError, lineWidth: .borderStandard)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Toast Notification

/// A toast notification for non-critical messages
struct ToastNotification: View {
    enum ToastType {
        case success
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .success:
                return Color.euniSuccess
            case .info:
                return Color.euniSecondary
            case .warning:
                return Color.orange
            case .error:
                return Color.euniError
            }
        }

        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .info:
                return "info.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            }
        }
    }

    let type: ToastType
    let message: String

    var body: some View {
        HStack(spacing: .spacingM) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            Text(message)
                .font(.body)
                .foregroundColor(Color.euniText)

            Spacer()
        }
        .padding(.spacingM)
        .background(Color.euniFieldBackground)
        .cornerRadius(.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusM)
                .stroke(type.color, lineWidth: .borderStandard)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - View Extension for Error Handling

extension View {
    /// Display an error banner
    func errorBanner(
        error: Binding<AppError?>,
        onRetry: (() -> Void)? = nil
    ) -> some View {
        ZStack(alignment: .top) {
            self

            if let currentError = error.wrappedValue {
                ErrorBanner(
                    error: currentError,
                    onRetry: onRetry,
                    onDismiss: {
                        error.wrappedValue = nil
                    }
                )
                .padding(.spacingM)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: error.wrappedValue)
                .zIndex(999)
            }
        }
    }

    /// Display a toast notification
    func toast(
        isPresented: Binding<Bool>,
        type: ToastNotification.ToastType = .info,
        message: String
    ) -> some View {
        ZStack(alignment: .bottom) {
            self

            if isPresented.wrappedValue {
                ToastNotification(type: type, message: message)
                    .padding(.spacingM)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: isPresented.wrappedValue)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isPresented.wrappedValue = false
                        }
                    }
                    .zIndex(999)
            }
        }
    }
}

// MARK: - Previews

#Preview("Error Banner") {
    @Previewable @State var error: AppError? = .networkError("Unable to connect to server")
    VStack {
        if let error = error {
            ErrorBanner(
                error: error,
                onRetry: { print("Retry") },
                onDismiss: { error = nil }
            )
        }
    }
    .padding()
}

#Preview("Toast Notifications") {
    VStack(spacing: .spacingL) {
        ToastNotification(type: .success, message: "Note saved successfully")
        ToastNotification(type: .info, message: "Loading your data...")
        ToastNotification(type: .warning, message: "Connection is slow")
        ToastNotification(type: .error, message: "Failed to save note")
    }
    .padding()
}
