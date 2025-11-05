//
//  DateTimeSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Date and time selection section for EasyNote
//

import SwiftUI

struct DateTimeSection: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader("Date & Time", subtitle: "When did this session occur?")

            HStack(spacing: .spacingL) {
                FormDatePickerRow("Date", date: $selectedDate, displayedComponents: [.date])
                    .frame(maxWidth: .infinity)

                FormDatePickerRow("Time", date: $selectedTime, displayedComponents: [.hourAndMinute])
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    @Previewable @State var date = Date()
    @Previewable @State var time = Date()

    DateTimeSection(selectedDate: $date, selectedTime: $time)
        .padding()
}
