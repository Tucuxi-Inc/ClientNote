//
//  ICDCodeSearchSection.swift
//  ClientNote
//
//  Created by AI Assistant
//  ICD-10 code search with autocomplete and favorites
//

import SwiftUI

struct ICDCodeSearchSection: View {
    @Binding var searchQuery: String
    @Binding var selectedCode: String
    @Binding var selectedDescription: String
    @Binding var icdResults: [ICDResult]
    @Binding var isSearching: Bool

    let onSearch: (String) async -> Void
    let recentCodes: [ICDResult]

    @State private var showingResults = false
    @StateObject private var debouncer = Debouncer(delay: 0.5)

    init(
        searchQuery: Binding<String>,
        selectedCode: Binding<String>,
        selectedDescription: Binding<String>,
        icdResults: Binding<[ICDResult]>,
        isSearching: Binding<Bool>,
        recentCodes: [ICDResult] = [],
        onSearch: @escaping (String) async -> Void
    ) {
        self._searchQuery = searchQuery
        self._selectedCode = selectedCode
        self._selectedDescription = selectedDescription
        self._icdResults = icdResults
        self._isSearching = isSearching
        self.recentCodes = recentCodes
        self.onSearch = onSearch
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingM) {
            FormSectionHeader(
                "ICD-10 Diagnosis Code",
                subtitle: "Search for diagnosis codes"
            )

            // Selected code display
            if !selectedCode.isEmpty {
                HStack(spacing: .spacingM) {
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Selected Code")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: .spacingS) {
                            Text(selectedCode)
                                .font(.body.weight(.semibold))
                                .foregroundColor(Color.euniPrimary)

                            Text(selectedDescription)
                                .font(.body)
                                .foregroundColor(Color.euniText)
                        }
                    }

                    Spacer()

                    Button(action: {
                        selectedCode = ""
                        selectedDescription = ""
                        searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.spacingM)
                .background(Color.euniSuccess.opacity(0.1))
                .cornerRadius(.cornerRadiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .stroke(Color.euniSuccess, lineWidth: .borderStandard)
                )
            }

            // Search field
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text("Search")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.euniText)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Enter diagnosis or code...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onChange(of: searchQuery) { newValue in
                            if !newValue.isEmpty && newValue.count >= 2 {
                                debouncer.debounce {
                                    Task {
                                        await performSearch(query: newValue)
                                    }
                                }
                                showingResults = true
                            } else {
                                showingResults = false
                            }
                        }

                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                    }

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            showingResults = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.spacingS)
                .background(Color.euniFieldBackground)
                .cornerRadius(.cornerRadiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .stroke(Color.euniBorder, lineWidth: .borderStandard)
                )
            }

            // Search results
            if showingResults && !icdResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Search Results")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.spacingS)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.euniFieldBackground.opacity(0.5))

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(icdResults) { result in
                                Button(action: {
                                    selectedCode = result.code
                                    selectedDescription = result.description
                                    searchQuery = ""
                                    showingResults = false
                                }) {
                                    HStack(spacing: .spacingM) {
                                        Text(result.code)
                                            .font(.body.weight(.semibold))
                                            .foregroundColor(Color.euniPrimary)
                                            .frame(width: 60, alignment: .leading)

                                        Text(result.description)
                                            .font(.body)
                                            .foregroundColor(Color.euniText)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding(.spacingS)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(
                                    Color.euniFieldBackground.opacity(0.0)
                                )
                                .onHover { hovering in
                                    // Future: Add hover effect
                                }

                                if result.id != icdResults.last?.id {
                                    Divider()
                                        .padding(.horizontal, .spacingS)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color.euniFieldBackground)
                .cornerRadius(.cornerRadiusS)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .stroke(Color.euniBorder, lineWidth: .borderStandard)
                )
            }

            // Recent codes
            if !recentCodes.isEmpty && selectedCode.isEmpty && searchQuery.isEmpty {
                VStack(alignment: .leading, spacing: .spacingS) {
                    Text("Recent Codes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: .spacingS) {
                        ForEach(recentCodes.prefix(5)) { code in
                            Button(action: {
                                selectedCode = code.code
                                selectedDescription = code.description
                            }) {
                                HStack(spacing: .spacingXS) {
                                    Text(code.code)
                                        .font(.caption.weight(.semibold))
                                    Text("•")
                                        .font(.caption)
                                    Text(code.description)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, .spacingS)
                                .padding(.vertical, .spacingXS)
                                .background(Color.euniFieldBackground)
                                .cornerRadius(.cornerRadiusS)
                                .overlay(
                                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                                        .stroke(Color.euniBorder, lineWidth: .borderStandard)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func performSearch(query: String) async {
        await onSearch(query)
    }
}

// MARK: - Flow Layout

/// A flow layout that wraps items horizontally
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    @Previewable @State var query = ""
    @Previewable @State var code = ""
    @Previewable @State var description = ""
    @Previewable @State var results: [ICDResult] = []
    @Previewable @State var isSearching = false

    ICDCodeSearchSection(
        searchQuery: $query,
        selectedCode: $code,
        selectedDescription: $description,
        icdResults: $results,
        isSearching: $isSearching,
        onSearch: { _ in }
    )
    .padding()
}

#Preview("With Selected") {
    @Previewable @State var query = ""
    @Previewable @State var code = "F41.1"
    @Previewable @State var description = "Generalized anxiety disorder"
    @Previewable @State var results: [ICDResult] = []
    @Previewable @State var isSearching = false

    ICDCodeSearchSection(
        searchQuery: $query,
        selectedCode: $code,
        selectedDescription: $description,
        icdResults: $results,
        isSearching: $isSearching,
        recentCodes: [
            ICDResult(code: "F41.1", description: "Generalized anxiety disorder"),
            ICDResult(code: "F32.9", description: "Major depressive disorder"),
            ICDResult(code: "F43.10", description: "Post-traumatic stress disorder")
        ],
        onSearch: { _ in }
    )
    .padding()
}
