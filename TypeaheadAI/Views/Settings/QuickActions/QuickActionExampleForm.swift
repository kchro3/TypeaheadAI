//
//  QuickActionExampleForm.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/2/23.
//

import SwiftUI

struct QuickActionExampleForm: View {
    @Environment(\.colorScheme) var colorScheme

    @State var copiedText: String = ""
    @State var pastedText: String = ""

    let onFetch: ((UUID) -> HistoryEntry?)?
    let onSubmit: ((String, String) -> Void)?
    let onCancel: (() -> Void)?

    let selectedRow: HistoryEntry.ID?
    private let descWidth: CGFloat = 60
    private let height: CGFloat = 300
    private let width: CGFloat = 400

    init(
        selectedRow: HistoryEntry.ID?,
        onFetch: ((UUID) -> HistoryEntry?)? = nil,
        onSubmit: ((String, String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.selectedRow = selectedRow
        self.onFetch = onFetch
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    var body: some View {
        VStack {
            // Copied Text
            HStack {
                Text("Sample Input")
                    .frame(width: descWidth)

                TextEditor(text: $copiedText)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .frame(minHeight: 50)
            }

            // Copied Text
            HStack {
                Text("Expected Output")
                    .frame(width: descWidth)

                TextEditor(text: $pastedText)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .frame(minHeight: 50)
            }

            // Submit or Cancel buttons
            HStack {
                Spacer()

                Button(action: {
                    onCancel?()
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
                    onSubmit?(copiedText, pastedText)
                }, label: {
                    Text("Create")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor)
                        )
                })
                .buttonStyle(.plain)
            }
        }
        .frame(width: width, height: height)
        .padding(15)
        .onAppear {
            if let selectedRow = selectedRow,
               let historyID = selectedRow,
               let entry = onFetch?(historyID) {
                copiedText = entry.copiedText ?? ""
                pastedText = entry.pastedResponse ?? ""
            } else {
                copiedText = ""
                pastedText = ""
            }
        }
    }
}
