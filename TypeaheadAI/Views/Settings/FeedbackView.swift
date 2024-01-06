//
//  FeedbackView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/22/23.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var feedback: String = ""
    var onSubmit: ((String) async throws -> Void)? = nil

    @State private var showAlert = false
    @State private var errorMessage: String? = nil

    private let maxCharacterCount = 4000

    var body: some View {
        VStack(alignment: .leading) {
            Text("Feedback").font(.title)

            Divider()

            Text(
                """
                Thanks for using Typeahead!

                If you experience any bugs or have a poor user experience, please let us know, and we will try to address them as soon as possible. We are also open to feature requests and suggestions!

                We may reach out by email to ask about more details. You can also reach me at @kchro3 on Twitter or jeff@typeahead.ai by email.
                """
            )

            Divider()

            TextEditor(text: $feedback)
                .font(.system(.body))
                .scrollContentBackground(.hidden)
                .lineLimit(10)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
                .overlay(
                    Group {
                        if feedback.isEmpty {
                            Text(
                                """
                                Please share your feedback here! Your feedback is valuable.
                                """)
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, 8)
                            .padding(.horizontal, 15)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: feedback) { newValue in
                    if newValue.count > maxCharacterCount {
                        feedback = String(newValue.prefix(maxCharacterCount))
                    }
                }

            Text("Character count: \(feedback.count)/\(maxCharacterCount)")
                .font(.footnote)
                .foregroundColor(feedback.count > maxCharacterCount ? .red : .primary)

            HStack {
                Spacer()

                RoundedButton("Submit", isAccent: true) {
                    if !feedback.isEmpty {
                        Task {
                            do {
                                try await onSubmit?(feedback)
                                feedback = ""
                                showAlert = true
                                errorMessage = nil
                            } catch {
                                showAlert = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                if errorMessage != nil {
                    Alert(title: Text("Failed to submit feedback"),
                          message: Text("Something went wrong... Please check your internet connection and make sure that you are signed in."),
                          dismissButton: .default(Text("OK"))
                    )
                } else {
                    Alert(title: Text("Your feedback has been received!"),
                          message: Text("Thank you for your feedback! We will review it as soon as possible and take it into consideration. Please feel free to reach out to @kchro3 on Twitter or jeff@typeahead.ai"),
                          dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

#Preview {
    FeedbackView()
}
