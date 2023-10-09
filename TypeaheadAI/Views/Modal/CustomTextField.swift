//
//  CustomTextField.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/25/23.
//

import CoreData
import SwiftUI

struct CustomTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedIndex: Int?
    @Binding var numberOfSuggestions: Int
    @Binding var caretRect: CGRect?
    @Binding var height: CGFloat

    var onTab: () -> Void
    var onEnter: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Style adjustments
        textView.backgroundColor = NSColor.clear
        textView.focusRingType = .none
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false

        DispatchQueue.main.async {
            // Initialize height
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let size = layoutManager.usedRect(for: textContainer).size
                self.height = size.height
            }
        }

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text

            DispatchQueue.main.async {
                // Initialize height
                if let layoutManager = nsView.layoutManager, let textContainer = nsView.textContainer {
                    layoutManager.ensureLayout(for: textContainer)
                    let size = layoutManager.usedRect(for: textContainer).size
                    self.height = size.height
                }
            }
        }
    }

    class Coordinator : NSObject, NSTextViewDelegate {
        var parent: CustomTextView

        init(_ parent: CustomTextView) {
            self.parent = parent
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let suggestionCount = parent.numberOfSuggestions
            if commandSelector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
                let event = NSApplication.shared.currentEvent
                if event?.modifierFlags.contains(.shift) == true {
                    // Shift-Enter pressed
                    textView.insertNewline(nil)
                    return true
                } else {
                    // Enter pressed
                    parent.onEnter(parent.text)
                    parent.text = ""
                    return true
                }
            } else if commandSelector == #selector(NSStandardKeyBindingResponding.insertTab(_:)) {
                parent.onTab()
                return true
            } else if commandSelector == #selector(NSStandardKeyBindingResponding.moveUp(_:)) {
                if suggestionCount > 0 {
                    parent.selectedIndex = ((parent.selectedIndex ?? 0) + suggestionCount - 1) % suggestionCount
                    return true
                }
            } else if commandSelector == #selector(NSStandardKeyBindingResponding.moveDown(_:)) {
                if suggestionCount > 0 {
                    parent.selectedIndex = ((parent.selectedIndex ?? -1) + 1) % suggestionCount
                    return true
                }
            }
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            DispatchQueue.main.async {
                self.parent.text = textView.string

                // Manually calculate the height of the text
                if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                    layoutManager.ensureLayout(for: textContainer)
                    let size = layoutManager.usedRect(for: textContainer).size
                    self.parent.height = size.height
                }
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            if let selectedRange = textView.selectedRanges.first as? NSRange {
                let text = textView.string as NSString
                let lastWordRange = text.range(of: "\\b\\w+$", options: .regularExpression, range: NSRange(location: 0, length: selectedRange.location))
                if lastWordRange.location != NSNotFound, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: lastWordRange, actualCharacterRange: nil)
                    let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    DispatchQueue.main.async {
                        self.parent.caretRect = rect
                    }
                }
            }
        }
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholderText: String
    let autoCompleteSuggestions: [PromptEntry]
    var onEnter: (String) -> Void

    @State private var showAutoComplete = false
    @State private var filteredSuggestions: [String] = []
    @State private var numberOfSuggestions: Int = 0
    @State private var selectedIndex: Int? = nil
    @State private var caretRect: CGRect? = nil
    @State private var height: CGFloat = 0
    @State private var inlineSuggestion: String = ""

    var body: some View {
        ZStack {
            CustomTextView(
                text: $text,
                selectedIndex: $selectedIndex,
                numberOfSuggestions: $numberOfSuggestions,
                caretRect: $caretRect,
                height: $height,
                onTab: {
                    if let index = selectedIndex {
                        applySuggestion(index: index)
                    }
                },
                onEnter: onEnter
            )
            .overlay(alignment: .topLeading) {
                Group {
                    if text.isEmpty && selectedIndex == nil {
                        Text(placeholderText)
                    } else if let idx = selectedIndex {
                        Text("\(filteredSuggestions[idx]) [tab]")
                    } else {
                        Text("")
                    }
                }
                .foregroundColor(Color.secondary.opacity(0.5))
                .padding(.horizontal, 5)
                .allowsHitTesting(false)
            }
            .frame(height: height)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 15)
                .fill(.secondary.opacity(0.1))
            )
            .onChange(of: text, perform: { value in
                filterSuggestions(input: value)
            })
            .onChange(of: selectedIndex ?? -1, perform: { value in
                // Populate inlineSuggestion
                if showAutoComplete {
                    inlineSuggestion = String(filteredSuggestions[value].dropFirst(text.count))
                } else {
                    inlineSuggestion = ""
                }
            })
            .onAppear(perform: {
                filterSuggestions(input: text)
            })
        }
    }

    private func filterSuggestions(input: String) {
        // Check for direct prefix-match
        filteredSuggestions = autoCompleteSuggestions.map { $0.prompt ?? "" } .filter {
            $0.lowercased().starts(with: input.lowercased()) && $0.lowercased() != input.lowercased()
        }
        numberOfSuggestions = filteredSuggestions.count
        showAutoComplete = !filteredSuggestions.isEmpty && !input.isEmpty

        if let firstSuggestion = filteredSuggestions.first, showAutoComplete {
            selectedIndex = 0  // set default selectedIndex
            inlineSuggestion = String(firstSuggestion.dropFirst(input.count))
        } else {
            selectedIndex = nil  // clear selectedIndex
            inlineSuggestion = ""
        }
    }

    private func applySuggestion(index: Int) {
        DispatchQueue.main.async {
            self.text = self.filteredSuggestions[index]
            self.showAutoComplete = false
            self.inlineSuggestion = ""
            self.selectedIndex = nil
        }
    }
}

#Preview {
    @State var text = ""

    // Create an in-memory Core Data store
    let container = NSPersistentContainer(name: "TypeaheadAI")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    let suggestions = ["apple", "banana", "orange", "grape", "watermelon"].map { prompt in
        let newPrompt = PromptEntry(context: container.viewContext)
        newPrompt.prompt = prompt
        return newPrompt
    }

    return CustomTextField(
        text: $text,
        placeholderText: "Placeholder",
        autoCompleteSuggestions: suggestions,
        onEnter: { res in print(res) }
    )
}
