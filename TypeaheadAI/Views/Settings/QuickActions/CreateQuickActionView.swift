//
//  CreateQuickActionView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/18/23.
//

import SwiftUI

struct CreateQuickActionView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var currentStep = 1
    @State var quickActionType: QuickActionType = .copyPaste
    @State var quickActionName: String = ""
    @State private var quickActionDetails: String = ""
    @State private var copyPasteInput: String = ""
    @State private var copyPasteOutput: String = ""

    var onSubmit: ((String, QuickActionType, String, String, String) -> Void)? = nil
    var onRecordStart: (() -> Void)? = nil
    var onRecordEnd: (((() -> String)?) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        if currentStep == 1 {
            initializeQuickAction
        } else if currentStep == 2 {
            configureQuickAction
        } else if currentStep == 3 {
            addExamplesQuickAction
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var initializeQuickAction: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {

                Text("Create a new Quick Action")
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Short and sweet nickname (required)", text: $quickActionName)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )

                Text("Select a mode")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                Picker("Action Type", selection: $quickActionType) {
                    ForEach([
                        QuickActionType.copyPaste,
                        QuickActionType.autopilot
                    ], id: \.self) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if quickActionType == .copyPaste {
                    Text("""
                    When you "smart-copy" a text, Typeahead will try to generate something to paste based on the context, and you can "smart-paste" the generated content into any app or website.

                    By configuring a Quick Action, you can add more details and examples to fine-tune the results.
                    """)
                } else {
                    Text("""
                    In Autopilot mode, Typeahead will try to plan and execute a series of actions to carry out a task. Typeahead can use "smart-copied" text as an input to the task.

                    By configuring a Quick Action, you can add more detailed instructions and record yourself doing the task once so that Typeahead can learn by example.
                    """)
                }
            }

            Spacer()

            HStack {
                RoundedButton("Cancel") {
                    onCancel?()
                }

                Spacer()

                RoundedButton("Continue", isAccent: true) {
                    if !quickActionName.isEmpty {
                        currentStep += 1
                    }
                }
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var configureQuickAction: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {

                Text("Configure Quick Action")
                    .font(.title2)
                    .fontWeight(.bold)

                if quickActionType == .copyPaste {
                    Text("""
                            When you smart-copy a text and say "\(quickActionName)", Typeahead will try to generate something to paste based on the context, and you can smart-paste the generated content into any app or website.

                            Explain what Typeahead should do with the copied text when you say "\(quickActionName)".
                            """)
                } else {
                    Text("""
                            Describe what Typeahead should do when you say "\(quickActionName)".

                            In Autopilot mode, Typeahead can process what's on the screen and decide what buttons and menus to click and what text fields to type into. You can also specify what apps or websites need to be opened.
                            """)
                }

                TextEditor(text: $quickActionDetails)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .overlay(
                        Group {
                            if quickActionDetails.isEmpty {
                                Text("""
                                Typeahead can understand natural language, so you can describe the task as you would to a new coworker or intern. You can use phrases and bullet points, and it is best to be concise while avoiding jargon.
                                """)
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.top, 8)
                                .padding(.horizontal, 15)
                                .transition(.opacity)
                            }
                        }.allowsHitTesting(false),
                        alignment: .topLeading
                    )
            }

            Spacer()

            HStack {
                RoundedButton("Cancel") {
                    onCancel?()
                }

                Spacer()

                RoundedButton("Back") {
                    currentStep -= 1
                }

                RoundedButton("Continue", isAccent: true) {
                    if !quickActionDetails.isEmpty {
                        currentStep += 1
                    }
                }
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private var addExamplesQuickAction: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {

                Text("Create an Example")
                    .font(.title2)
                    .fontWeight(.bold)

                if quickActionType == .autopilot {
                    Text("""
                    Typeahead can learn by example, so if you record yourself doing the "\(quickActionName)" Quick Action once, Typeahead will try to copy how you did it.
                    """)
                } else {
                    Text("""
                    Typeahead can learn from past examples, so the more you use the "\(quickActionName)" Quick Action, the better it can recognize patterns.

                    Try adding an example of something you would smart-copy and an ideal response when you say "\(quickActionName)".
                    """)
                }

                if quickActionType == .autopilot {
                    HStack {
                        TextEditor(text: $copyPasteInput)
                            .font(.system(.body))
                            .scrollContentBackground(.hidden)
                            .lineLimit(nil)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            )
                            .overlay(
                                Group {
                                    if copyPasteInput.isEmpty {
                                        Text("""
                                        Add an example of some copied text.

                                        Leave blank if the Quick Action does not need an input.
                                        """)
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .padding(.top, 8)
                                        .padding(.horizontal, 15)
                                        .transition(.opacity)
                                    }
                                }.allowsHitTesting(false),
                                alignment: .topLeading
                            )

                        TextEditor(text: $humanReadablePlan)
                            .font(.system(.body))
                            .scrollContentBackground(.hidden)
                            .lineLimit(nil)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            )
                            .overlay(
                                Group {
                                    if copyPasteOutput.isEmpty {
                                        Text("After you record yourself, Typeahead will generate an action plan, and you can edit it as needed here.")
                                            .foregroundColor(.secondary.opacity(0.4))
                                            .padding(.top, 8)
                                            .padding(.horizontal, 15)
                                            .transition(.opacity)
                                    }
                                }.allowsHitTesting(false),
                                alignment: .topLeading
                            )
                    }
                } else {
                    HStack {
                        TextEditor(text: $copyPasteInput)
                            .font(.system(.body))
                            .scrollContentBackground(.hidden)
                            .lineLimit(nil)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            )
                            .overlay(
                                Group {
                                    if copyPasteInput.isEmpty {
                                        Text("Add an example of some copied text.")
                                            .foregroundColor(.secondary.opacity(0.4))
                                            .padding(.top, 8)
                                            .padding(.horizontal, 15)
                                            .transition(.opacity)
                                    }
                                }.allowsHitTesting(false),
                                alignment: .topLeading
                            )

                        TextEditor(text: $copyPasteOutput)
                            .font(.system(.body))
                            .scrollContentBackground(.hidden)
                            .lineLimit(nil)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            )
                            .overlay(
                                Group {
                                    if copyPasteOutput.isEmpty {
                                        Text("Add an example of an ideal response.")
                                            .foregroundColor(.secondary.opacity(0.4))
                                            .padding(.top, 8)
                                            .padding(.horizontal, 15)
                                            .transition(.opacity)
                                    }
                                }.allowsHitTesting(false),
                                alignment: .topLeading
                            )
                    }
                }
            }

            Spacer()

            HStack {
                RoundedButton("Cancel") {
                    onCancel?()
                }

                Spacer()

                RoundedButton("Back") {
                    currentStep -= 1
                }

                if quickActionType == .autopilot {
                    if copyPasteOutput.isEmpty {
                        Button {
                            self.onRecordStart?()
                        } label: {
                            HStack {
                                Image(systemName: "record.circle")
                                Text("Record")
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .foregroundStyle(.white)
                            .background(RoundedRectangle(cornerRadius: 15)
                                .fill(Color.red)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        RoundedButton("Save", isAccent: true) {
                            if !quickActionName.isEmpty,
                               !quickActionDetails.isEmpty,
                               (!copyPasteInput.isEmpty || quickActionType == .autopilot),
                               !copyPasteOutput.isEmpty {
                                self.onSubmit?(
                                    quickActionName,
                                    quickActionType,
                                    quickActionDetails,
                                    copyPasteInput,
                                    copyPasteOutput
                                )
                            }
                        }
                    }
                } else {
                    RoundedButton("Save", isAccent: true) {
                        if !quickActionName.isEmpty,
                           !quickActionDetails.isEmpty,
                           (!copyPasteInput.isEmpty || quickActionType == .autopilot),
                           !copyPasteOutput.isEmpty {
                            self.onSubmit?(
                                quickActionName,
                                quickActionType,
                                quickActionDetails,
                                copyPasteInput,
                                copyPasteOutput
                            )
                        }
                    }
                }
            }
        }
        .padding(10)
    }
}

#Preview {
    CreateQuickActionView(humanReadablePlan: .constant(""))
}

#Preview {
    CreateQuickActionView(humanReadablePlan: .constant(""), currentStep: 2, quickActionType: .copyPaste, quickActionName: "Test Quick Action")
}

#Preview {
    CreateQuickActionView(humanReadablePlan: .constant(""), currentStep: 2, quickActionType: .autopilot, quickActionName: "Test Quick Action")
}

#Preview {
    CreateQuickActionView(humanReadablePlan: .constant(""), currentStep: 3, quickActionType: .copyPaste, quickActionName: "Test Quick Action")
}

#Preview {
    CreateQuickActionView(humanReadablePlan: .constant(""), currentStep: 3, quickActionType: .autopilot, quickActionName: "Test Quick Action")
}
