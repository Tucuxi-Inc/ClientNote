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

Copyright (c) <year> <copyright holders>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
---
© 2025 Tucuxi. Inc. Euni™ is a trademark of Tucuxi, Inc. All rights reserved.
