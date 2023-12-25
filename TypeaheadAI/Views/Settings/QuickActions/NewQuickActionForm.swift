//
//  NewQuickActionForm.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/1/23.
//

import SwiftUI

struct NewQuickActionForm: View {
    @State var newLabel: String = ""
    @State var newDetails: String = ""
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme
    private let descWidth: CGFloat = 70
    private let verticalPadding: CGFloat = 8  // For text-fields
    private let height: CGFloat = 300
    private let width: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading) {
            Text("New Quick Action")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text("Label")
                    .frame(width: descWidth, alignment: .trailing)

                TextField("Label", text: $newLabel)
                    .textFieldStyle(.plain)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
            }

            // Details
            HStack(alignment: .top) {
                Text("Prompt")
                    .padding(.top, 5)
                    .frame(width: descWidth, alignment: .trailing)

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
                        },
                        alignment: .topLeading
                    )
            }

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
        .frame(width: width, height: height)
        .padding(15)
    }
}

#Preview {
    NewQuickActionForm(onSubmit: { _, _ in }, onCancel: { })
}
