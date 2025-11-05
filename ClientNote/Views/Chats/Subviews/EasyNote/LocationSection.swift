//
//  LocationSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  Session location selection with visual indicators
//

import SwiftUI

struct LocationSection: View {
    @Binding var selectedLocation: String

    let locations = [
        "In-Person",
        "First Telehealth Visit",
        "Subsequent Telehealth Visit"
    ]

    private func iconForLocation(_ location: String) -> String {
        switch location {
        case "In-Person":
            return "person.fill"
        case "First Telehealth Visit":
            return "video.fill"
        case "Subsequent Telehealth Visit":
            return "video.badge.checkmark"
        default:
            return "mappin.circle.fill"
        }
    }

    private func descriptionForLocation(_ location: String) -> String {
        switch location {
        case "In-Person":
            return "Face-to-face session at office or clinic"
        case "First Telehealth Visit":
            return "Initial remote session via video call"
        case "Subsequent Telehealth Visit":
            return "Follow-up remote session via video call"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader(
                "Session Location",
                subtitle: "Select where the session took place"
            )

            VStack(spacing: .spacingS) {
                ForEach(locations, id: \.self) { location in
                    Button(action: {
                        selectedLocation = location
                    }) {
                        HStack(spacing: .spacingM) {
                            // Radio button indicator
                            Image(systemName: selectedLocation == location ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(selectedLocation == location ? Color.euniPrimary : Color.secondary)
                                .font(.title3)

                            // Location icon
                            Image(systemName: iconForLocation(location))
                                .foregroundColor(selectedLocation == location ? Color.euniPrimary : Color.euniSecondary)
                                .font(.title3)
                                .frame(width: 24)

                            // Location details
                            VStack(alignment: .leading, spacing: .spacingXS) {
                                Text(location)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(Color.euniText)

                                Text(descriptionForLocation(location))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()
                        }
                        .padding(.spacingM)
                        .background(
                            selectedLocation == location
                                ? Color.euniPrimary.opacity(0.1)
                                : Color.euniFieldBackground
                        )
                        .cornerRadius(.cornerRadiusM)
                        .overlay(
                            RoundedRectangle(cornerRadius: .cornerRadiusM)
                                .stroke(
                                    selectedLocation == location
                                        ? Color.euniPrimary
                                        : Color.euniBorder,
                                    lineWidth: selectedLocation == location ? 2 : .borderStandard
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Information about billing codes
            if selectedLocation == "First Telehealth Visit" {
                HStack(spacing: .spacingS) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color.euniSecondary)
                    Text("First telehealth visits may require different billing codes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.spacingS)
                .background(Color.euniSecondary.opacity(0.1))
                .cornerRadius(.cornerRadiusS)
            }
        }
    }
}

// MARK: - Preview

#Preview("In-Person Selected") {
    @Previewable @State var location = "In-Person"

    LocationSection(selectedLocation: $location)
        .padding()
}

#Preview("First Telehealth Selected") {
    @Previewable @State var location = "First Telehealth Visit"

    LocationSection(selectedLocation: $location)
        .padding()
}

#Preview("Subsequent Telehealth Selected") {
    @Previewable @State var location = "Subsequent Telehealth Visit"

    LocationSection(selectedLocation: $location)
        .padding()
}
