# Euni™ - Client Notes

Euni™ - Client Notes is a powerful macOS application designed for mental health professionals to streamline their clinical documentation process. Using advanced AI technology, the app helps clinicians generate comprehensive, insurance-ready psychotherapy notes while maintaining professional standards and clinical accuracy.

## Key Features

- **AI-Powered Note Generation**: Leverages advanced language models to create detailed clinical notes
- **Multiple Input Methods**: Choose between traditional free-form entry or structured EasyNote forms
- **Professional Clinical Language**: Ensures proper terminology and formatting for insurance requirements
- **Secure Local Processing**: All processing happens locally on your machine using Ollama
- **Customizable Note Formats**: Supports various note formats (SOAP, BIRP, DAP, etc.)
- **Voice Input Support**: Dictate your notes using built-in speech recognition
- **ICD-10 Code Integration**: Quick access to diagnostic codes
- **Client Management**: Organize notes by client and session

## Session Note Generation Process

Euni™ uses a sophisticated two-pass analysis system to generate high-quality clinical notes. Here's how it works:

### Input Methods

1. **Traditional Entry**
   - Type or dictate your session notes freely
   - Include any relevant observations, interventions, and client responses
   - Natural language processing identifies therapeutic techniques and client engagement

2. **EasyNote Form**
   - Structured form for quick, guided input
   - Select specific therapeutic approaches and interventions
   - Document client responses and engagement
   - Add additional notes through typing or dictation
   - Includes fields for:
     - Session information (date, time, location)
     - Therapeutic approaches used
     - Specific interventions applied
     - Client response and engagement
     - Treatment goals and progress
     - Risk assessments when applicable

### Smart Analysis System

The app performs two intelligent analyses on your input:

1. **Therapeutic Modalities Analysis**
   - Identifies therapeutic techniques and interventions used
   - Recognizes evidence-based practices (CBT, DBT, ACT, etc.)
   - Maps specific interventions to therapeutic approaches
   - Ensures accurate clinical terminology

2. **Client Engagement Analysis**
   - Evaluates client responsiveness and participation
   - Assesses engagement across multiple dimensions:
     - General receptiveness
     - Active listening
     - Response to interventions
     - Nonverbal communication
     - Commitment to treatment
   - Provides professional descriptions of client engagement

### Note Generation

The app combines these analyses with your input to generate a comprehensive clinical note that:

- Uses proper clinical terminology and phrasing
- Follows your chosen note format
- Integrates therapeutic techniques appropriately
- Describes client engagement professionally
- Maintains insurance-ready documentation standards
- Includes relevant diagnostic codes
- Documents risk assessments when needed

### Professional Standards

All generated notes adhere to:
- Insurance documentation requirements
- Clinical best practices
- Professional documentation standards
- Proper clinical terminology
- Appropriate level of detail

## Privacy and Security

- All note generation happens locally on your machine
- No clinical data is sent to external servers
- Client data is stored securely on your device
- Compliant with clinical documentation standards

## Recent Development Work

### Major Bug Fixes and System Improvements

The following section documents significant debugging and improvement work completed to resolve critical issues with the chat system, AI generation workflows, and user experience.

#### 1. Chat Data Persistence System Overhaul

**Problem**: Chat content was not being saved or loaded correctly, with aggressive filtering removing legitimate user content during save operations.

**Solution**: Complete rewrite of `saveActivityContent()` in `ChatViewModel.swift`:
- Removed overly aggressive duplicate detection that was filtering out valid user messages
- Implemented highly specific analysis prompt detection using exact string matching
- Added comprehensive debug logging throughout the save/load pipeline
- Streamlined `loadActivityChat()` to trust already-filtered save data format

#### 2. Two-Pass Generation Cleanup

**Problem**: The two-pass AI generation system was creating messy chat displays with multiple intermediate messages, analysis artifacts, and confusing user interfaces.

**Solution**: Streamlined generation workflow in `handleGenerateAction()`:
- Eliminated intermediate message creation during two-pass analysis
- Implemented clean user prompt + final response display pattern
- Improved loading state management with proper UI feedback
- Separated analysis processing from user-visible chat content

#### 3. Analysis System Isolation

**Problem**: The `generateAnalysis()` function was using `MessageViewModel` which created temporary messages that polluted the main chat interface.

**Solution**: Complete rewrite using direct `OllamaKit` API calls:
- Eliminated ALL temporary message creation during analysis
- Implemented pure API-based analysis without UI side effects
- Maintained analysis functionality while keeping chat interface clean
- Added proper error handling for analysis failures

#### 4. Activity Switching and State Management

**Problem**: Switching between different activity types (Session Notes, Treatment Plans, Brainstorm) wasn't properly clearing chat state, leading to content contamination between activities.

**Solution**: Enhanced activity management in `onActivitySelected()`:
- Added robust client validation and recursive correction for invalid selections
- Improved state synchronization between activity types
- Fixed onChange handlers in `ChatView.swift` to properly handle activity switching
- Restored critical `updateSystemPrompt()` calls for proper activity isolation

#### 5. Format Parameter Debugging

**Problem**: Note format overrides (like EasyNote PIRP format) were being ignored, defaulting to SOAP format instead.

**Solution**: Added comprehensive format debugging pipeline:
- Implemented detailed logging in `generateStructuredNote()` tracking format parameter flow
- Added parameter tracing from `noteFormat` → `selectedNoteFormat` → `formatToUse`
- Enhanced debug output to identify where format parameters are lost or overridden

#### 6. System Architecture Improvements

**Code Quality Enhancements**:
- Added extensive debug logging throughout critical code paths
- Implemented proper error handling and recovery mechanisms
- Created comprehensive testing checklist for all major workflows
- Documented complex interaction patterns between ViewModels

**Performance Optimizations**:
- Eliminated unnecessary UI updates during background processing
- Streamlined chat loading and saving operations
- Reduced memory overhead by removing temporary message objects

#### 7. Developer Documentation

**Created comprehensive codebase documentation**:
- `CODEBASE_SUMMARY.md` with detailed architecture overview
- Complete mapping of data flow between major components
- Testing procedures for all three activity workflows
- Debug feature documentation for troubleshooting

### Known Issues and Future Work

**Current Focus Areas**:
- Activity isolation refinement (ensuring complete separation between activity types)
- Format parameter handling in complex generation workflows
- Streaming feedback implementation for two-pass generation progress
- Enhanced error recovery and user feedback mechanisms

**Testing Status**:
- Core two-pass functionality: ✅ Working
- Session note generation: ✅ Working  
- Activity switching: 🔄 Improved, refinement ongoing
- Format override handling: 🔍 Under investigation
- Chat history isolation: 🔄 Improved, testing ongoing

### Development Environment

**Build Status**: ✅ All code compiles successfully with `xcodebuild`
**Debug Features**: Comprehensive logging enabled throughout chat system
**Test Coverage**: Manual testing procedures documented for all major workflows

## Testing the CodePolishing Branch

The `claude/CodePolishing-011CUp4D3NC6NfjiwBeAuSmF` branch contains significant UI/UX improvements and code refactoring. This section explains how to pull, build, and test these changes.

### What's New in CodePolishing

**Phase 1 - High Priority Improvements**:
- ✅ Full dark mode support with adaptive colors
- ✅ Standardized spacing system (XS to XXXL)
- ✅ Professional button styles with animations
- ✅ Accessibility improvements (VoiceOver support)
- ✅ Activity search with keyboard shortcuts (⌘K)
- ✅ Empty states with clear guidance
- ✅ Extracted recording classes for better code organization

**Phase 2 - Medium Priority Improvements**:
- ✅ Keyboard shortcuts system
- ✅ Reusable form components (6 types)
- ✅ Centralized error handling with user-friendly messages
- ✅ Performance optimizations (debouncing, caching, lazy loading)
- ✅ Export functionality (TXT, RTF, PDF, Markdown)
- ✅ Started EasyNote component refactoring

**Phase 3 - EasyNote Refactoring**:
- ✅ Refactored EasyNoteSheet from 1076 lines to 484 lines (55% reduction)
- ✅ Created 7 modular sub-components:
  - DateTimeSection - Session date/time selection
  - LocationSection - In-person vs telehealth with visual indicators
  - TherapeuticApproachSection - 15 approaches with 150+ interventions
  - ClinicalFieldsSection - Presenting issue, client response, clinical focus, treatment goals
  - RiskAssessmentSection - Suicidal ideation tracking with safety reminders
  - ICDCodeSearchSection - Live ICD-10 code search with autocomplete
  - AdditionalNotesSection - Notes + voice recording
- ✅ Integrated export button into ChatPreferencesView
- ✅ Updated documentation (CONTRIBUTING.md, TESTING.md)

### Quick Start - Testing the Branch

**Prerequisites**:
- macOS 14.0 or later
- Xcode 15.0 or later
- Ollama installed and running with a model downloaded

**Steps**:

1. **Clone and checkout the branch**:
   ```bash
   git clone https://github.com/Tucuxi-Inc/ClientNote.git
   cd ClientNote
   git checkout claude/CodePolishing-011CUp4D3NC6NfjiwBeAuSmF
   ```

2. **Open in Xcode**:
   ```bash
   open ClientNote.xcodeproj
   ```

3. **Build and Run**:
   - Wait for Xcode to finish indexing
   - Select "My Mac" as the destination (Product → Destination)
   - Press `⌘B` to build
   - Press `⌘R` to run

4. **Initial Configuration**:
   - Open Settings (gear icon)
   - Verify Ollama configuration: `http://localhost:11434`
   - Select your model from the dropdown
   - Create a test client

5. **Test the New Features**:
   - **Dark Mode**: Switch system appearance and verify colors adapt
   - **Search**: Press `⌘K` to focus search, filter activities
   - **Export**: Generate a note → Gear icon → Export section → Export as PDF
   - **EasyNote Form**: Create session note → Click EasyNote button → Fill out structured form
     - Test ICD code search (type "anxiety", select F41.1)
     - Test therapeutic approach selection with interventions
     - Test voice recording button (requires microphone permission)
     - Watch preview update in real-time
     - Generate note and verify all form data is included

### Comprehensive Testing Guide

For detailed testing procedures, see **[TESTING.md](TESTING.md)** which includes:
- Complete test checklist for all phases
- Step-by-step testing scenarios
- Integration and regression testing
- Performance testing guidelines
- Issue reporting template

### Code Architecture Documentation

For developers wanting to understand or contribute to the codebase, see **[CONTRIBUTING.md](CONTRIBUTING.md)** which covers:
- Project architecture and structure
- Design system (spacing, colors, buttons)
- Component-based architecture explanation
- EasyNote refactoring details
- Code style guidelines
- Common patterns and best practices

### Performance Notes

The refactored codebase includes several performance optimizations:
- **Debouncing**: ICD search waits 500ms before querying API
- **Lazy Loading**: Large lists use `LazyVStack` for efficiency
- **Image Caching**: Automatic caching for loaded images
- **Component Composition**: Reduced re-renders with focused components

### Files Changed

**Created (20 files)**:
- `Extensions/Spacing+Constants.swift` - Design system constants
- `Utils/ButtonStyles.swift` - Standardized button styles
- `Utils/FormComponents.swift` - Reusable form elements
- `Utils/ErrorHandling.swift` - Error management system
- `Utils/PerformanceOptimizations.swift` - Caching and performance utilities
- `Utils/ExportHelper.swift` - Export functionality (4 formats)
- `Utils/KeyboardShortcuts.swift` - Keyboard shortcut definitions
- `Utils/EmptyStateView.swift` - Empty state component
- `ViewModels/RecordingViewModel.swift` - Audio recording logic
- `ViewModels/SpeakerIdentifier.swift` - Voice profile tracking
- `ViewModels/TranscriptManager.swift` - Transcript management
- `Views/Chats/Subviews/TranscriptView.swift` - Transcript display
- `Views/Chats/Subviews/EasyNote/DateTimeSection.swift` - Date/time component
- `Views/Chats/Subviews/EasyNote/LocationSection.swift` - Location component
- `Views/Chats/Subviews/EasyNote/TherapeuticApproachSection.swift` - Approach component
- `Views/Chats/Subviews/EasyNote/ClinicalFieldsSection.swift` - Clinical fields component
- `Views/Chats/Subviews/EasyNote/RiskAssessmentSection.swift` - Risk assessment component
- `Views/Chats/Subviews/EasyNote/ICDCodeSearchSection.swift` - ICD search component
- `Views/Chats/Subviews/EasyNote/AdditionalNotesSection.swift` - Notes component
- `Views/Chats/Subviews/EasyNote/README.md` - Component documentation

**Modified (9 files)**:
- `Extensions/Color+ClientNoteCustom.swift` - Dark mode support
- `Views/Chats/ChatView.swift` - Documentation updates
- `Views/Chats/Subviews/AssistantMessageView.swift` - Spacing and styling
- `Views/Chats/Subviews/CircleButton.swift` - Accessibility
- `Views/Chats/Subviews/MessageButton.swift` - Accessibility
- `Views/Chats/Subviews/EasyNoteSheet.swift` - Major refactoring (1076→484 lines)
- `Views/Chats/ChatPreferencesView.swift` - Export integration
- `Views/Sidebar/SidebarView.swift` - Search functionality
- `README.md` - This file

## Development Setup

### Ollama Setup

1. Install Ollama on your Mac
2. Download a compatible model (e.g., `ollama pull qwen:0.6b`)
3. Configure Euni™ to use Ollama in settings

## Getting Started

1. Complete the development setup above (Ollama)
2. Launch Euni™ - Client Notes
3. Configure your preferred note format in settings
4. Add your first client
5. Start creating professional clinical notes

## Requirements

- macOS 14.0 or later
- Ollama installed and running
- Internet connection (for ICD-10 code lookup or to operate in OpenAI mode (with your own developer key from OpenAI))

## Support

For support, questions, or feedback, please contact kevin@tucuxi.ai

## License

Copyright (c) 2025 Tucuxi, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---
© 2025 Tucuxi. Inc. Euni™ is a trademark of Tucuxi, Inc. All rights reserved.
