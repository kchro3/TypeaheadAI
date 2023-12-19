//
//  NewQuickActionForm.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/1/23.
//

import SwiftUI

struct NewQuickActionForm: View {
    @State private var newLabel: String = ""
    @State private var newDetails: String = ""
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme
    private let descWidth: CGFloat = 70
    private let verticalPadding: CGFloat = 8  // For text-fields
    private let height: CGFloat = 300
    private let width: CGFloat = 400

    @State private var selectedActionType = QuickActionType.copyPaste

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Create a new Quick Action")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Short and sweet nickname (required)", text: $newLabel)
                    .textFieldStyle(.plain)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )

                Picker("Action Type", selection: $selectedActionType) {
                    ForEach([
                        QuickActionType.copyPaste,
                        QuickActionType.autopilot
                    ], id: \.self) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if selectedActionType == .autopilot {
                    autopilotWorkflow
                } else {
                    smartCopySmartPaste
                }

                Spacer()

                HStack {
                    Spacer()

                    Button(action: {
                        onCancel()
                    }, label: {
                        Text("Cancel")
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            )
                    })
                    .buttonStyle(.plain)

                    Button(action: {
                        onSubmit(newLabel, newDetails)
                    }, label: {
                        Text("Create")
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(Color.accentColor)
                            )
                    })
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: width, height: height)
        .padding(15)
    }

    @ViewBuilder
    private var smartCopySmartPaste: some View {
        VStack {
            // Details
            VStack(alignment: .leading) {
                Text("Details")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                TextEditor(text: $newDetails)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .overlay(
                        Group {
                            if newDetails.isEmpty {
                                Text(
                                        """
                                        Explain what Typeahead should do with the copied text.
                                        """)
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.top, verticalPadding)
                                .padding(.horizontal, 15)
                                .transition(.opacity)
                            }
                        }.allowsHitTesting(false),
                        alignment: .topLeading
                    )
                    .frame(minHeight: 100)
            }

            // Examples
            VStack(alignment: .leading) {
                Text("Examples")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                TextEditor(text: $newDetails)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .overlay(
                        Group {
                            if newDetails.isEmpty {
                                Text(
                                        """
                                        Explain what Typeahead should do with the copied text.
                                        """)
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.top, verticalPadding)
                                .padding(.horizontal, 15)
                                .transition(.opacity)
                            }
                        }.allowsHitTesting(false),
                        alignment: .topLeading
                    )
            }
        }
    }

    @ViewBuilder
    private var autopilotWorkflow: some View {
        // Details
        VStack(alignment: .leading) {
            Text("Prompt")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            TextEditor(text: $newDetails)
                .font(.system(.body))
                .scrollContentBackground(.hidden)
                .lineLimit(nil)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
                .overlay(
                    Group {
                        if newDetails.isEmpty {
                            Text(
                                    """
                                    Explain what you want this action to do.
                                    """)
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, verticalPadding)
                            .padding(.horizontal, 15)
                            .transition(.opacity)
                        }
                    }.allowsHitTesting(false),
                    alignment: .topLeading
                )
                .frame(minHeight: 100)
        }
    }
}

#Preview {
    NewQuickActionForm(onSubmit: { _, _ in }, onCancel: { })
}
