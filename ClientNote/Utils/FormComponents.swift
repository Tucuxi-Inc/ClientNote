//
//  FormComponents.swift
//  ClientNote
//
//  Created by AI Assistant
//  Reusable form components for consistent UI
//

import SwiftUI

// MARK: - Form Text Field

/// A styled text field for forms with consistent appearance
struct FormTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let multiline: Bool

    init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        multiline: Bool = false
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.multiline = multiline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.euniText)

            if multiline {
                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 80)
                    .padding(.spacingS)
                    .background(Color.euniFieldBackground)
                    .cornerRadius(.cornerRadiusS)
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusS)
                            .stroke(Color.euniBorder, lineWidth: .borderStandard)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .padding(.spacingS)
                    .background(Color.euniFieldBackground)
                    .cornerRadius(.cornerRadiusS)
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusS)
                            .stroke(Color.euniBorder, lineWidth: .borderStandard)
                    )
            }
        }
    }
}

// MARK: - Form Picker Row

/// A picker row for forms with label and selection
struct FormPickerRow<SelectionValue: Hashable>: View {
    let label: String
    @Binding var selection: SelectionValue
    let options: [SelectionValue]
    let displayName: (SelectionValue) -> String

    init(
        _ label: String,
        selection: Binding<SelectionValue>,
        options: [SelectionValue],
        displayName: @escaping (SelectionValue) -> String = { "\($0)" }
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.displayName = displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.euniText)

            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(displayName(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.spacingS)
            .background(Color.euniFieldBackground)
            .cornerRadius(.cornerRadiusS)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusS)
                    .stroke(Color.euniBorder, lineWidth: .borderStandard)
            )
        }
    }
}

// MARK: - Form Date Picker Row

/// A date picker row for forms with label and selection
struct FormDatePickerRow: View {
    let label: String
    @Binding var date: Date
    let displayedComponents: DatePickerComponents

    init(
        _ label: String,
        date: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute]
    ) {
        self.label = label
        self._date = date
        self.displayedComponents = displayedComponents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color.euniText)

            DatePicker(
                "",
                selection: $date,
                displayedComponents: displayedComponents
            )
            .datePickerStyle(.field)
            .padding(.spacingS)
            .background(Color.euniFieldBackground)
            .cornerRadius(.cornerRadiusS)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusS)
                    .stroke(Color.euniBorder, lineWidth: .borderStandard)
            )
        }
    }
}

// MARK: - Form Section Header

/// A section header for forms with consistent styling
struct FormSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(Color.euniText)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, .spacingM)
    }
}

// MARK: - Form Toggle Row

/// A toggle row for forms with label and binding
struct FormToggleRow: View {
    let label: String
    let description: String?
    @Binding var isOn: Bool

    init(_ label: String, isOn: Binding<Bool>, description: String? = nil) {
        self.label = label
        self._isOn = isOn
        self.description = description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(label)
                        .font(.body)
                        .foregroundColor(Color.euniText)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
        }
        .padding(.spacingS)
        .background(Color.euniFieldBackground)
        .cornerRadius(.cornerRadiusS)
    }
}

// MARK: - Form Divider

/// A subtle divider for form sections
struct FormDivider: View {
    var body: some View {
        Divider()
            .background(Color.euniBorder)
            .padding(.vertical, .spacingM)
    }
}

// MARK: - Previews

#Preview("Form Text Field") {
    @Previewable @State var text = ""
    VStack {
        FormTextField("Name", text: $text, placeholder: "Enter name")
        FormTextField("Notes", text: $text, placeholder: "Enter notes", multiline: true)
    }
    .padding()
}

#Preview("Form Picker") {
    @Previewable @State var selection = "Option 1"
    FormPickerRow("Choose Option", selection: $selection, options: ["Option 1", "Option 2", "Option 3"])
        .padding()
}

#Preview("Form Date Picker") {
    @Previewable @State var date = Date()
    FormDatePickerRow("Session Date", date: $date)
        .padding()
}

#Preview("Form Section") {
    VStack(alignment: .leading) {
        FormSectionHeader("Personal Information", subtitle: "Enter your details below")
        FormDivider()
        FormSectionHeader("Contact Information")
    }
    .padding()
}
