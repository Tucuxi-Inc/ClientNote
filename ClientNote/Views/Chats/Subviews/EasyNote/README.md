# EasyNote Sub-Components

This directory contains modular sub-components extracted from the large EasyNoteSheet.swift file for better maintainability and reusability.

## Components

### ✅ DateTimeSection
**File**: `DateTimeSection.swift`
**Purpose**: Date and time selection for session notes
**Props**:
- `selectedDate: Binding<Date>` - The session date
- `selectedTime: Binding<Date>` - The session time

**Usage**:
```swift
DateTimeSection(selectedDate: $selectedDate, selectedTime: $selectedTime)
```

---

### ✅ TherapeuticApproachSection
**File**: `TherapeuticApproachSection.swift`
**Purpose**: Therapeutic approach selection with interventions checklist
**Props**:
- `selectedApproach: Binding<String>` - Selected therapeutic approach
- `customApproach: Binding<String>` - Custom approach text (when "Other" selected)
- `selectedInterventions: Binding<Set<String>>` - Set of selected interventions

**Features**:
- 15 pre-defined therapeutic approaches
- Dynamic interventions list based on selected approach
- Custom approach text field for "Other"
- Selected interventions counter
- "Clear All" functionality

**Usage**:
```swift
TherapeuticApproachSection(
    selectedApproach: $selectedApproach,
    customApproach: $customApproach,
    selectedInterventions: $selectedInterventions
)
```

---

### ✅ RiskAssessmentSection
**File**: `RiskAssessmentSection.swift`
**Purpose**: Suicidal ideation and self-harm risk assessment
**Props**:
- `hasSuicidalIdeation: Binding<Bool>` - Main toggle for risk presence
- `suicidalIdeationPastSession: Binding<Bool>` - Risk between sessions
- `suicidalIdeationCurrentSession: Binding<Bool>` - Risk during current session
- `suicidalIdeationBothSessions: Binding<Bool>` - Risk in both time periods

**Features**:
- Conditional display of time frame options
- Visual warning indicators (red borders, error colors)
- Safety planning reminder

**Usage**:
```swift
RiskAssessmentSection(
    hasSuicidalIdeation: $hasSuicidalIdeation,
    suicidalIdeationPastSession: $suicidalIdeationPastSession,
    suicidalIdeationCurrentSession: $suicidalIdeationCurrentSession,
    suicidalIdeationBothSessions: $suicidalIdeationBothSessions
)
```

---

### ✅ ICDCodeSearchSection
**File**: `ICDCodeSearchSection.swift`
**Purpose**: ICD-10 code search with autocomplete and recent codes
**Props**:
- `searchQuery: Binding<String>` - Search text
- `selectedCode: Binding<String>` - Selected ICD code
- `selectedDescription: Binding<String>` - Code description
- `icdResults: Binding<[ICDResult]>` - Search results
- `isSearching: Binding<Bool>` - Loading state
- `recentCodes: [ICDResult]` - Recently used codes
- `onSearch: (String) async -> Void` - Search callback

**Features**:
- Debounced search (0.5s delay)
- Selected code display with clear button
- Scrollable search results (max 200pt height)
- Recent codes quick selection
- FlowLayout for tags
- Visual feedback with colors

**Usage**:
```swift
ICDCodeSearchSection(
    searchQuery: $insuranceQuery,
    selectedCode: $selectedICDCode,
    selectedDescription: $selectedICDDescription,
    icdResults: $icdResults,
    isSearching: $isSearchingICD,
    recentCodes: recentCodes,
    onSearch: { query in await performICDSearch(query) }
)
```

---

### ✅ ClinicalFieldsSection
**File**: `ClinicalFieldsSection.swift`
**Purpose**: Core clinical fields (presenting issue, client response, focus, goals)
**Props**:
- `presentingIssue: Binding<String>` - Presenting issue selection
- `customPresentingIssue: Binding<String>` - Custom presenting issue
- `clientResponse: Binding<String>` - Client response/engagement
- `customClientResponse: Binding<String>` - Custom client response
- `clinicalFocus: Binding<String>` - Clinical focus area
- `customClinicalFocus: Binding<String>` - Custom clinical focus
- `treatmentGoals: Binding<String>` - Treatment goals
- `customTreatmentGoals: Binding<String>` - Custom treatment goals

**Features**:
- 8 presenting issue options
- 6 client response options
- 6 clinical focus options
- 5 treatment goals options
- Custom "Other" text fields for all categories
- Uses FormPickerRow and FormTextField components

**Usage**:
```swift
ClinicalFieldsSection(
    presentingIssue: $presentingIssue,
    customPresentingIssue: $customPresentingIssue,
    clientResponse: $clientResponse,
    customClientResponse: $customClientResponse,
    clinicalFocus: $clinicalFocus,
    customClinicalFocus: $customClinicalFocus,
    treatmentGoals: $treatmentGoals,
    customTreatmentGoals: $customTreatmentGoals
)
```

---

### ✅ LocationSection
**File**: `LocationSection.swift`
**Purpose**: Session location selection with visual indicators
**Props**:
- `selectedLocation: Binding<String>` - Location type
- Options: In-Person, First Telehealth, Subsequent Telehealth

**Features**:
- Radio button selection
- Location-specific icons (person, video, video.badge.checkmark)
- Descriptions for each location type
- Visual selection state (highlighted border, background)
- Billing code information for first telehealth visits
- Accessible button design

**Usage**:
```swift
LocationSection(selectedLocation: $selectedLocation)
```

---

### ✅ AdditionalNotesSection
**File**: `AdditionalNotesSection.swift`
**Purpose**: Free-form notes with voice recording support
**Props**:
- `additionalNotes: Binding<String>` - Notes text
- `isRecording: Binding<Bool>` - Recording state
- `onStartRecording: () -> Void` - Start callback
- `onStopRecording: () -> Void` - Stop callback
- `recordingPermissionGranted: Bool` - Permission status

**Features**:
- Voice recording controls (start/stop)
- Recording indicator with animation
- Character count display
- TextEditor with placeholder
- Permission request alert
- Tips for content suggestions
- System Preferences deep link for permissions

**Usage**:
```swift
AdditionalNotesSection(
    additionalNotes: $additionalNotes,
    isRecording: $isRecording,
    onStartRecording: { startRecording() },
    onStopRecording: { stopRecording() },
    recordingPermissionGranted: hasPermission
)
```

---

## Refactoring Plan for EasyNoteSheet

### Phase 1: Extract All Sections ✅ COMPLETED
- [x] DateTimeSection
- [x] TherapeuticApproachSection
- [x] RiskAssessmentSection
- [x] ICDCodeSearchSection
- [x] ClinicalFieldsSection
- [x] LocationSection
- [x] AdditionalNotesSection

### Phase 2: Refactor Main Sheet
Simplify EasyNoteSheet.swift to compose sub-components:

```swift
struct EasyNoteSheet: View {
    // All @State properties

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingL) {
                FormSectionHeader("Create Session Note")

                DateTimeSection(
                    selectedDate: $selectedDate,
                    selectedTime: $selectedTime
                )

                FormDivider()

                TherapeuticApproachSection(
                    selectedApproach: $selectedApproach,
                    customApproach: $customApproach,
                    selectedInterventions: $selectedInterventions
                )

                FormDivider()

                ClinicalFieldsSection(...)

                FormDivider()

                RiskAssessmentSection(...)

                FormDivider()

                ICDCodeSearchSection(...)

                FormDivider()

                AdditionalNotesSection(...)

                // Action Buttons
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.euniSecondary)

                    Button("Generate Note") { generateAction() }
                        .buttonStyle(.euniPrimary)
                }
            }
            .padding()
        }
    }
}
```

### Phase 3: Benefits
- **Maintainability**: Each section is independently editable
- **Reusability**: Sections can be reused in other forms
- **Testing**: Components can be tested individually
- **Performance**: Lazy loading of sections
- **Readability**: Main sheet becomes a simple composition

---

## Design Patterns Used

### Composition over Inheritance
Each section is a standalone View that accepts bindings, making them composable building blocks.

### Single Responsibility
Each component handles one specific aspect of the form (date selection, risk assessment, etc.).

### Consistent Styling
All components use:
- `FormSectionHeader` for titles
- `FormTextField`, `FormPickerRow` for inputs
- Spacing constants from `Spacing+Constants.swift`
- Euni color palette from `Color+ClientNoteCustom.swift`

---

## Usage in Parent View

```swift
import SwiftUI

struct EasyNoteSheet: View {
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedApproach = "CBT (Cognitive Behavioral Therapy)"
    @State private var customApproach = ""
    @State private var selectedInterventions: Set<String> = []
    @State private var hasSuicidalIdeation = false
    @State private var suicidalIdeationPastSession = false
    @State private var suicidalIdeationCurrentSession = false
    @State private var suicidalIdeationBothSessions = false

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingXL) {
                DateTimeSection(
                    selectedDate: $selectedDate,
                    selectedTime: $selectedTime
                )

                FormDivider()

                TherapeuticApproachSection(
                    selectedApproach: $selectedApproach,
                    customApproach: $customApproach,
                    selectedInterventions: $selectedInterventions
                )

                FormDivider()

                RiskAssessmentSection(
                    hasSuicidalIdeation: $hasSuicidalIdeation,
                    suicidalIdeationPastSession: $suicidalIdeationPastSession,
                    suicidalIdeationCurrentSession: $suicidalIdeationCurrentSession,
                    suicidalIdeationBothSessions: $suicidalIdeationBothSessions
                )
            }
            .padding()
        }
    }
}
```

---

## Future Improvements

1. **Validation**: Add input validation to each section
2. **Persistence**: Save draft states automatically
3. **Templates**: Create preset templates for common scenarios
4. **Accessibility**: Enhanced VoiceOver support for all fields
5. **Help Text**: Contextual help popovers for each section
6. **Recent Selections**: Remember recently used options
7. **Smart Defaults**: Suggest interventions based on approach

---

**Last Updated**: 2025-11-05
**Status**: Phase 1 - ✅ COMPLETED (7 of 7 components created)

**Next Step**: Phase 2 - Refactor main EasyNoteSheet.swift to compose all sub-components
