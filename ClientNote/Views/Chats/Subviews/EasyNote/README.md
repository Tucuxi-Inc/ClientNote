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

## Pending Components (To Be Created)

### 🔲 ICDCodeSearchSection
**Proposed File**: `ICDCodeSearchSection.swift`
**Purpose**: ICD-10 code search with autocomplete
**Proposed Props**:
- `searchQuery: Binding<String>` - Search text
- `selectedCode: Binding<String>` - Selected ICD code
- `selectedDescription: Binding<String>` - Code description
- `recentCodes: [ICDResult]` - Recently used codes
- `favoriteCodes: [ICDResult]` - Favorited codes

---

### 🔲 ClinicalFieldsSection
**Proposed File**: `ClinicalFieldsSection.swift`
**Purpose**: Core clinical fields (presenting issue, client response, focus, goals)
**Proposed Props**:
- `presentingIssue: Binding<String>` - Presenting issue
- `clientResponse: Binding<String>` - Client response/engagement
- `clinicalFocus: Binding<String>` - Clinical focus area
- `treatmentGoals: Binding<String>` - Treatment goals
- Custom variants for each field

---

### 🔲 LocationSection
**Proposed File**: `LocationSection.swift`
**Purpose**: Session location selection
**Proposed Props**:
- `selectedLocation: Binding<String>` - Location type
- Options: In-Person, First Telehealth, Subsequent Telehealth

---

### 🔲 AdditionalNotesSection
**Proposed File**: `AdditionalNotesSection.swift`
**Purpose**: Free-form notes with voice recording
**Proposed Props**:
- `additionalNotes: Binding<String>` - Notes text
- `isRecording: Binding<Bool>` - Recording state
- Voice recording controls

---

## Refactoring Plan for EasyNoteSheet

### Phase 1: Extract All Sections ✅ IN PROGRESS
- [x] DateTimeSection
- [x] TherapeuticApproachSection
- [x] RiskAssessmentSection
- [ ] ICDCodeSearchSection
- [ ] ClinicalFieldsSection
- [ ] LocationSection
- [ ] AdditionalNotesSection

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
**Status**: Phase 1 - Partial (3 of 7 components created)
