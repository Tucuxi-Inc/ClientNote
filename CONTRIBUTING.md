# Contributing to Euni™ - Client Notes

This document provides architectural information and guidelines for developers working on the Euni™ codebase.

## Architecture Overview

Euni™ is built using SwiftUI with a modern, component-based architecture designed for maintainability and scalability.

### Core Technologies

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage
- **OllamaKit**: Local AI model integration
- **Speech Framework**: Voice recording and transcription
- **AVFoundation**: Audio processing

### Project Structure

```
ClientNote/
├── Extensions/
│   ├── Color+ClientNoteCustom.swift    # Dark mode adaptive colors
│   └── Spacing+Constants.swift         # Design system constants
├── Models/
│   ├── Client.swift                    # Client data model
│   └── Activity.swift                  # Activity/session data model
├── ViewModels/
│   ├── ChatViewModel.swift             # Chat state management
│   ├── MessageViewModel.swift          # Message handling
│   ├── RecordingViewModel.swift        # Audio recording logic
│   ├── SpeakerIdentifier.swift         # Voice profile tracking
│   └── TranscriptManager.swift         # Transcript management
├── Views/
│   ├── Chats/
│   │   ├── ChatView.swift              # Main chat interface
│   │   └── Subviews/
│   │       ├── EasyNoteSheet.swift     # Structured note form (refactored)
│   │       └── EasyNote/               # Modular form components
│   │           ├── DateTimeSection.swift
│   │           ├── LocationSection.swift
│   │           ├── TherapeuticApproachSection.swift
│   │           ├── ClinicalFieldsSection.swift
│   │           ├── RiskAssessmentSection.swift
│   │           ├── ICDCodeSearchSection.swift
│   │           └── AdditionalNotesSection.swift
│   └── Sidebar/
│       └── SidebarView.swift           # Client/activity sidebar
└── Utils/
    ├── ButtonStyles.swift              # Standardized button styles
    ├── FormComponents.swift            # Reusable form elements
    ├── ErrorHandling.swift             # Error management system
    ├── PerformanceOptimizations.swift  # Caching and lazy loading
    ├── ExportHelper.swift              # Export functionality
    └── KeyboardShortcuts.swift         # Keyboard shortcut definitions
```

## Design System

### Spacing Constants

All spacing in the app follows a standardized system defined in `Extensions/Spacing+Constants.swift`:

```swift
.spacingXS    // 4pt  - Minimal gaps
.spacingS     // 8pt  - Small spacing
.spacingM     // 12pt - Default spacing
.spacingL     // 16pt - Large spacing
.spacingXL    // 20pt - Extra large spacing
.spacingXXL   // 24pt - Double extra large
.spacingXXXL  // 32pt - Maximum spacing
```

**Usage Example**:
```swift
VStack(spacing: .spacingM) {
    Text("Title")
    Text("Content")
}
.padding(.spacingL)
```

### Color System

Colors are adaptive and support both light and dark modes:

```swift
Color.euniPrimary       // Main brand color
Color.euniSecondary     // Secondary accents
Color.euniBackground    // Main background
Color.euniText          // Primary text
Color.euniFieldBackground // Form field backgrounds
Color.euniBorder        // Border colors
Color.euniSuccess       // Success states
Color.euniError         // Error states
```

Colors automatically adapt based on system appearance. Implementation uses `NSColor` with light/dark variants.

### Button Styles

Five standardized button styles are available:

```swift
Button("Primary Action") { }
    .buttonStyle(.euniPrimary)

Button("Secondary Action") { }
    .buttonStyle(.euniSecondary)

Button("Delete") { }
    .buttonStyle(.euniDestructive)

Button("Link") { }
    .buttonStyle(.euniBorderless)

Button { } label: { Image(systemName: "gear") }
    .buttonStyle(.euniIcon)
```

## Component-Based Architecture

### Form Components

The app uses reusable form components for consistent UI:

**FormTextField** - Standard text input
```swift
FormTextField(
    "Label",
    text: $binding,
    placeholder: "Enter text...",
    multiline: false
)
```

**FormPickerRow** - Dropdown selection
```swift
FormPickerRow(
    "Label",
    selection: $selectedValue,
    options: ["Option 1", "Option 2"],
    displayName: { $0 }
)
```

**FormDatePickerRow** - Date/time picker
```swift
FormDatePickerRow(
    "Label",
    selection: $date,
    displayedComponents: [.date, .hourAndMinute]
)
```

**FormSectionHeader** - Section titles
```swift
FormSectionHeader(
    "Section Title",
    subtitle: "Optional description"
)
```

**FormToggleRow** - Toggle switches
```swift
FormToggleRow(
    "Enable Feature",
    isOn: $enabled,
    description: "Optional description"
)
```

**FormDivider** - Visual separators
```swift
FormDivider()
```

### EasyNote Refactoring

The `EasyNoteSheet.swift` file was refactored from **1076 lines to 484 lines** (55% reduction) by extracting inline form code into 7 modular components:

#### Component Structure

1. **DateTimeSection** (39 lines)
   - Session date and time selection
   - Uses FormDatePickerRow components

2. **LocationSection** (116 lines)
   - In-Person vs Telehealth selection
   - Visual radio button UI with icons
   - Billing code information

3. **TherapeuticApproachSection** (181 lines)
   - 15 therapeutic approaches (CBT, DBT, ACT, etc.)
   - Dynamic intervention lists (150+ interventions)
   - Multi-select capability

4. **ClinicalFieldsSection** (153 lines)
   - Presenting issue selection
   - Client response/engagement
   - Clinical focus areas
   - Treatment goals

5. **RiskAssessmentSection** (144 lines)
   - Suicidal ideation tracking
   - Time frame assessment
   - Visual warnings and safety reminders

6. **ICDCodeSearchSection** (321 lines)
   - Live ICD-10 code search via NLM API
   - Debounced search (500ms delay)
   - Recent codes display with FlowLayout
   - Selected code visual feedback

7. **AdditionalNotesSection** (140 lines)
   - Free-form text input
   - Voice recording controls
   - Animated recording indicator
   - Character count display

#### Main Sheet Composition

`EasyNoteSheet.swift` now cleanly composes these components:

```swift
var body: some View {
    VStack(spacing: 0) {
        HStack(spacing: .spacingXL) {
            // LEFT COLUMN - Form
            ScrollView {
                VStack(alignment: .leading, spacing: .spacingL) {
                    DateTimeSection(...)
                    FormDivider()
                    LocationSection(...)
                    FormDivider()
                    TherapeuticApproachSection(...)
                    FormDivider()
                    ClinicalFieldsSection(...)
                    FormDivider()
                    RiskAssessmentSection(...)
                    FormDivider()
                    ICDCodeSearchSection(...)
                    FormDivider()
                    AdditionalNotesSection(...)
                }
            }

            // RIGHT COLUMN - Preview
            VStack {
                Text("Generated Prompt Preview")
                ScrollView {
                    Text(fullPrompt)
                }
            }
        }

        // Action Buttons
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Button("Generate Note") { handleGenerate() }
        }
    }
}
```

#### Benefits of Component Architecture

1. **Maintainability**: Each component is self-contained and focused
2. **Reusability**: Components can be used in other contexts
3. **Testability**: Components can be tested in isolation
4. **Preview Support**: Each component has its own SwiftUI previews
5. **Reduced Complexity**: Smaller files are easier to understand
6. **Better Git Diffs**: Changes to one section don't affect others

## Performance Optimizations

### Debouncing

Used for search fields to reduce API calls:

```swift
@StateObject private var debouncer = Debouncer(delay: 0.5)

TextField("Search", text: $query)
    .onChange(of: query) { newValue in
        debouncer.debounce {
            performSearch(newValue)
        }
    }
```

### Image Caching

Automatic caching for loaded images:

```swift
ImageCache.shared.load(from: url)
```

### Lazy Loading

Use `LazyVStack` and `LazyHStack` for long lists:

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
}
```

## Error Handling

The app uses a centralized error handling system:

```swift
enum AppError: LocalizedError {
    case network(String)
    case fileSystem(String)
    case validation(String)
    case ai(String)
    case audio(String)
    case general(String)
}
```

**Display errors to users**:
```swift
@State private var error: AppError?

SomeView()
    .errorBanner($error)
```

**Show toast notifications**:
```swift
SomeView()
    .toastNotification($showToast, message: "Success!")
```

## Export Functionality

Export to multiple formats using `ExportHelper`:

```swift
ExportButton(
    content: noteContent,
    fileName: "session_note"
)
```

Supported formats:
- Plain Text (.txt)
- Rich Text Format (.rtf)
- PDF (.pdf)
- Markdown (.md)

## Accessibility

All custom controls include proper accessibility support:

```swift
Button { action() }
    .accessibilityLabel("Descriptive label")
    .accessibilityHint("What happens when activated")
    .accessibilityAddTraits(.isButton)
```

## Code Style Guidelines

### MARK Comments

Use MARK comments to organize code sections:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Body
// MARK: - Actions
// MARK: - Helper Methods
```

### Naming Conventions

- **Variables**: camelCase (`selectedDate`, `isRecording`)
- **Functions**: camelCase with verb prefix (`handleGenerate`, `updatePreview`)
- **Types**: PascalCase (`EasyNoteSheet`, `FormTextField`)
- **Private members**: prefix with `private` keyword

### SwiftUI Patterns

**State Management**:
```swift
@State private var localState: String = ""           // Local state
@Binding var sharedState: String                      // Passed from parent
@Environment(\.dismiss) private var dismiss           // Environment
@StateObject private var viewModel = ViewModel()      // Observable object
```

**Computed Properties for Views**:
```swift
private var sectionHeader: some View {
    Text("Section Title")
        .font(.headline)
}
```

## Testing

Each component includes SwiftUI Preview macros for visual testing:

```swift
#Preview("Default State") {
    @Previewable @State var value = ""

    ComponentView(value: $value)
        .padding()
}

#Preview("With Content") {
    @Previewable @State var value = "Sample content"

    ComponentView(value: $value)
        .padding()
}
```

See `TESTING.md` for comprehensive testing procedures.

## Common Patterns

### Async/Await for API Calls

```swift
func performSearch(query: String) async {
    isLoading = true
    defer { isLoading = false }

    do {
        let results = try await searchAPI(query)
        self.results = results
    } catch {
        self.error = .network(error.localizedDescription)
    }
}
```

### Conditional Modifiers

```swift
Text("Content")
    .foregroundColor(isActive ? .euniPrimary : .secondary)
    .font(isLarge ? .title : .body)
```

### Custom Layout

Implementing custom layouts with the `Layout` protocol:

```swift
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Calculate size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Position subviews
    }
}
```

## Git Workflow

### Branch Naming

Follow the convention: `claude/<feature-name>-<session-id>`

Example: `claude/CodePolishing-011CUp4D3NC6NfjiwBeAuSmF`

### Commit Messages

Use descriptive commit messages:

```
feat: Complete EasyNote components and integrate export functionality

- Created 4 remaining EasyNote sub-components
- Integrated ExportButton into ChatPreferencesView
- Updated documentation
```

## Questions and Support

For questions about the codebase or contributions, contact kevin@tucuxi.ai

---

© 2025 Tucuxi, Inc. All rights reserved.
