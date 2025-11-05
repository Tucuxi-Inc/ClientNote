# Testing Guide for Euni™ - Client Notes

This guide provides comprehensive testing procedures for the CodePolishing branch improvements.

## Prerequisites

Before testing, ensure you have:

- ✅ macOS 14.0 or later
- ✅ Xcode 15.0 or later
- ✅ Ollama installed and running
- ✅ At least one model downloaded (e.g., `ollama pull qwen:0.6b`)

## Getting Started

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/Tucuxi-Inc/ClientNote.git
cd ClientNote

# Checkout the CodePolishing branch
git fetch origin
git checkout claude/CodePolishing-011CUp4D3NC6NfjiwBeAuSmF

# Verify you're on the correct branch
git branch
```

### 2. Open in Xcode

```bash
# Open the project
open ClientNote.xcodeproj
```

Or double-click `ClientNote.xcodeproj` in Finder.

### 3. Configure Xcode

1. Wait for Xcode to finish indexing
2. Select your Mac as the build destination (Product → Destination → My Mac)
3. Build the project: `⌘B` (Command + B)
4. Run the app: `⌘R` (Command + R)

### 4. Initial App Configuration

When you first launch the app:

1. Go to Settings (gear icon)
2. Under "AI Configuration", ensure Ollama is selected
3. Verify the host URL: `http://localhost:11434`
4. Select a model from the dropdown (should show models you've pulled)
5. Create a test client to use during testing

## Testing Checklist

### ✅ Phase 1: Dark Mode Support

**Test Objective**: Verify dark mode adapts correctly

1. Open Euni™ in light mode
2. Note the color scheme (buttons, backgrounds, text)
3. Switch to dark mode: System Settings → Appearance → Dark
4. Return to Euni™ and verify:
   - [ ] Primary buttons have darker green shade
   - [ ] Background colors have adjusted
   - [ ] Text remains readable
   - [ ] Form fields are visible
   - [ ] Borders are subtle but visible

**Expected Results**:
- All colors should automatically adapt
- No jarring contrast issues
- Consistent visual hierarchy in both modes

---

### ✅ Phase 1: Spacing System

**Test Objective**: Verify consistent spacing throughout UI

1. Navigate through different views
2. Check spacing consistency:
   - [ ] Sidebar padding is uniform
   - [ ] Chat messages have consistent gaps
   - [ ] Form fields in EasyNote have regular spacing
   - [ ] Button groups have proper spacing
   - [ ] No awkward gaps or cramped areas

**Expected Results**:
- Visual rhythm and consistency
- Professional, polished appearance

---

### ✅ Phase 1: Button Styles

**Test Objective**: Test new standardized button styles

1. Navigate to various screens and identify buttons
2. Test primary buttons (Generate, Save, etc.):
   - [ ] Hover effect works
   - [ ] Click animation appears
   - [ ] Disabled state shows grayed out
3. Test secondary buttons (Cancel, etc.):
   - [ ] Different appearance from primary
   - [ ] Hover and click effects work
4. Test destructive buttons (Delete, etc.):
   - [ ] Red/warning color
   - [ ] Hover effect works

**Expected Results**:
- Consistent button behavior
- Clear visual hierarchy
- Smooth animations

---

### ✅ Phase 1: Empty States

**Test Objective**: Verify empty state displays

1. Create a new client with no activities
2. Select the client
3. Verify empty state shows:
   - [ ] Illustrative icon
   - [ ] "No activities yet" message
   - [ ] Helpful description
   - [ ] "New Activity" button (if applicable)

**Expected Results**:
- Clear guidance when no content exists
- Actionable next steps

---

### ✅ Phase 1: Search Functionality

**Test Objective**: Test activity search in sidebar

1. Create multiple activities with different names
2. Use the search field in the sidebar
3. Test search:
   - [ ] Type partial name → filters correctly
   - [ ] Clear search → shows all activities
   - [ ] Case-insensitive search works
   - [ ] No results shows empty state
4. Test keyboard shortcut:
   - [ ] Press `⌘K` → search field gains focus
   - [ ] Press `Escape` → search field loses focus

**Expected Results**:
- Instant filtering as you type
- Clear indication of filtered results
- Easy to clear search

---

### ✅ Phase 1: Accessibility

**Test Objective**: Verify VoiceOver support

1. Enable VoiceOver: System Settings → Accessibility → VoiceOver
2. Navigate through the app
3. Verify:
   - [ ] Buttons announce their purpose
   - [ ] Form fields have clear labels
   - [ ] Current selection is announced
   - [ ] Hints explain what actions do

**Expected Results**:
- VoiceOver can navigate entire app
- All controls have meaningful labels

---

### ✅ Phase 2: Keyboard Shortcuts

**Test Objective**: Test keyboard shortcuts

1. Open the app
2. Test shortcuts:
   - [ ] `⌘K` → Focus search field
   - [ ] `⌘N` → New activity (if implemented)
   - [ ] `⌘Return` → Submit/Generate (in forms)
   - [ ] `Escape` → Dismiss sheets/dialogs

**Expected Results**:
- Shortcuts work reliably
- No conflicts with system shortcuts

---

### ✅ Phase 2: Form Components

**Test Objective**: Test reusable form components

1. Open any form (Settings, EasyNote, etc.)
2. Test each form element:
   - [ ] Text fields accept input
   - [ ] Placeholders show when empty
   - [ ] Pickers show all options
   - [ ] Date pickers work correctly
   - [ ] Toggles switch states
   - [ ] Sections have clear headers

**Expected Results**:
- Consistent form appearance
- All inputs functional
- Clear visual feedback

---

### ✅ Phase 2: Error Handling

**Test Objective**: Test error display system

1. Trigger various errors (e.g., disconnect Ollama)
2. Verify error handling:
   - [ ] Network errors show clear messages
   - [ ] File errors are reported
   - [ ] Validation errors appear inline
   - [ ] Toast notifications appear/disappear
   - [ ] Error banners are dismissible

**Expected Results**:
- Clear, actionable error messages
- No silent failures
- Users understand what went wrong

---

### ✅ Phase 2: Export Functionality

**Test Objective**: Test note export feature

1. Generate a session note (use existing or create new)
2. Navigate to the export section
3. Test each export format:
   - [ ] **Plain Text (.txt)** → Opens in TextEdit
   - [ ] **Rich Text (.rtf)** → Opens with formatting
   - [ ] **PDF (.pdf)** → Opens in Preview
   - [ ] **Markdown (.md)** → Opens in text editor
4. Verify exported content:
   - [ ] All note content is preserved
   - [ ] Formatting is appropriate for format
   - [ ] Special characters render correctly

**Test Locations**:
- Export button in ChatPreferencesView (gear icon)

**Expected Results**:
- All formats export successfully
- Save dialog appears with suggested filename
- Exported files open correctly

---

### ✅ Phase 3: EasyNote Components

**Test Objective**: Test refactored EasyNote form

1. Create a new session note activity
2. Click the "EasyNote" button (sheet icon)
3. Verify the form appears with all sections

#### DateTimeSection
- [ ] Date picker shows current date
- [ ] Time picker shows current time
- [ ] Both pickers are editable
- [ ] Selected values appear in preview

#### LocationSection
- [ ] Three location options display
- [ ] Each has icon and description
- [ ] Radio button selection works
- [ ] Selected location highlights
- [ ] Info message shows for "First Telehealth Visit"

#### TherapeuticApproachSection
- [ ] Dropdown shows 15 approaches
- [ ] Selecting approach updates intervention list
- [ ] Interventions can be multi-selected
- [ ] Custom approach field appears for "Other"
- [ ] Selected items show in preview

#### ClinicalFieldsSection
- [ ] All four fields display (presenting issue, client response, clinical focus, treatment goals)
- [ ] Each dropdown shows appropriate options
- [ ] "Other" selection reveals custom text field
- [ ] Values update preview in real-time

#### RiskAssessmentSection
- [ ] Main toggle for "Suicidal Ideation" works
- [ ] Expanding shows time frame options
- [ ] Warning styling is visible (red/orange)
- [ ] Safety reminder appears
- [ ] Assessment appears in preview when enabled

#### ICDCodeSearchSection
- [ ] Search field accepts input
- [ ] Debouncing works (doesn't search on every keystroke)
- [ ] Results appear after 500ms delay
- [ ] Clicking result selects it
- [ ] Selected code displays prominently
- [ ] Can clear selected code
- [ ] Recent codes display (if applicable)

**Test ICD Search**:
1. Type "anxiety" → wait → verify results appear
2. Click "F41.1 Generalized anxiety disorder"
3. Verify it appears in "Selected Code" box
4. Check preview includes diagnosis
5. Click X to clear selection

#### AdditionalNotesSection
- [ ] Text editor accepts input
- [ ] Placeholder text shows when empty
- [ ] Character count displays
- [ ] Recording button appears
- [ ] Click record → indicator animates
- [ ] Stop recording button works
- [ ] Permission alert shows if needed
- [ ] Tip message displays when appropriate

**Preview Column**:
- [ ] Preview updates in real-time as fields change
- [ ] All entered information appears in preview
- [ ] Preview is scrollable
- [ ] Preview uses proper formatting

**Action Buttons**:
- [ ] Cancel button dismisses sheet
- [ ] Generate button creates note
- [ ] `⌘Return` also generates note

**Expected Results**:
- All components render correctly
- Form is responsive and smooth
- No lag when updating preview
- All user inputs are captured

---

### ✅ Integration Testing

**Test Objective**: Full workflow end-to-end

**Scenario 1: Create Session Note with EasyNote**

1. Create new client "Test Patient"
2. Create new activity → "Session Note"
3. Click EasyNote button
4. Fill out form:
   - Set date/time to today
   - Select "In-Person" location
   - Choose "CBT" therapeutic approach
   - Select 2-3 interventions
   - Set presenting issue to "Anxiety"
   - Fill other clinical fields
   - Search and select ICD code "F41.1"
   - Add additional notes
5. Verify preview updates continuously
6. Click "Generate Note"
7. Verify:
   - [ ] Sheet dismisses
   - [ ] AI begins generating
   - [ ] Note appears in chat
   - [ ] Note follows selected format
   - [ ] All form data is included

**Scenario 2: Export Generated Note**

1. With generated note from above
2. Click gear icon (Chat Preferences)
3. Navigate to "Export" section
4. Try exporting as PDF
5. Save to Desktop
6. Verify:
   - [ ] File saves successfully
   - [ ] PDF opens in Preview
   - [ ] Content is complete and formatted

**Scenario 3: Switch Between Activities**

1. Create multiple activities
2. Switch between them
3. Verify:
   - [ ] Chat content loads correctly
   - [ ] No content from other activities appears
   - [ ] System prompts update appropriately
   - [ ] UI state updates correctly

---

## Performance Testing

### Memory Usage

1. Open Activity Monitor
2. Find ClientNote process
3. Use the app for 10-15 minutes
4. Verify:
   - [ ] Memory stays reasonable (< 500 MB)
   - [ ] No continuous memory growth
   - [ ] No memory leaks

### Responsiveness

1. Fill out large EasyNote form
2. Type in additional notes field
3. Verify:
   - [ ] UI remains responsive
   - [ ] Preview updates smoothly
   - [ ] No lag when typing

### Search Performance

1. Create 50+ activities
2. Use search feature
3. Verify:
   - [ ] Search results appear instantly
   - [ ] No lag when typing
   - [ ] Scrolling is smooth

---

## Regression Testing

### Core Functionality

Verify existing features still work:

- [ ] Create new client
- [ ] Create new activity
- [ ] Generate session note (traditional method)
- [ ] Save and load activities
- [ ] Delete activities
- [ ] Two-pass AI generation
- [ ] Voice recording in chat
- [ ] Settings changes persist
- [ ] Theme switching works

---

## Known Issues

Document any issues you encounter:

### Issue Template

```
**Issue**: Brief description
**Steps to Reproduce**:
1. Step one
2. Step two
3. etc.

**Expected Behavior**: What should happen
**Actual Behavior**: What actually happens
**Environment**: macOS version, Xcode version, branch
```

---

## Reporting Test Results

After completing testing, report your findings:

### Success Criteria

- [ ] All Phase 1 tests pass
- [ ] All Phase 2 tests pass
- [ ] All Phase 3 tests pass
- [ ] Integration tests pass
- [ ] Performance is acceptable
- [ ] No regressions found

### Test Summary Template

```markdown
## Test Results - CodePolishing Branch

**Date**: YYYY-MM-DD
**Tester**: Your Name
**Environment**:
- macOS: Version
- Xcode: Version
- Branch: claude/CodePolishing-011CUp4D3NC6NfjiwBeAuSmF
- Commit: [hash]

### Results

**Phase 1 (High Priority)**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
- Details...

**Phase 2 (Medium Priority)**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
- Details...

**Phase 3 (EasyNote Components)**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
- Details...

**Integration**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
- Details...

**Performance**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
- Details...

### Issues Found

1. [Issue description with severity: Critical/High/Medium/Low]
2. [Issue description]

### Recommendations

- [Any recommendations for improvements]
```

---

## Support

If you encounter issues during testing:

1. Check the console for error messages (Xcode → View → Debug Area → Show Debug Area)
2. Review logs in the app
3. Contact: kevin@tucuxi.ai

---

© 2025 Tucuxi, Inc. All rights reserved.
