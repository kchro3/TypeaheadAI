//
//  CustomTextField.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/25/23.
//

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
    let autoCompleteSuggestions: [String]
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
                    if text.isEmpty {
                        Text(placeholderText)
                    } else if !inlineSuggestion.isEmpty {
                        Text("\(text)\(inlineSuggestion) [tab]")
                    } else {
                        Text("\(text)")
                    }
                }
                .foregroundColor(Color.secondary.opacity(0.5))
                .padding(.horizontal, 5)
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
                if let lastWord = text.split(separator: " ").last, showAutoComplete {
                    inlineSuggestion = String(filteredSuggestions[value].dropFirst(lastWord.count))
                } else {
                    inlineSuggestion = ""
                }
            })
        }
    }

    private func filterSuggestions(input: String) {
        let words = input.split(separator: " ")
        guard let lastWord = words.last else {
            showAutoComplete = false
            inlineSuggestion = ""
            selectedIndex = nil  // clear selectedIndex
            return
        }
        filteredSuggestions = autoCompleteSuggestions.filter {
            $0.lowercased().starts(with: lastWord.lowercased()) && $0.lowercased() != lastWord.lowercased()
        }
        numberOfSuggestions = filteredSuggestions.count
        showAutoComplete = !filteredSuggestions.isEmpty

        if showAutoComplete {
            selectedIndex = 0  // set default selectedIndex
        } else {
            selectedIndex = nil  // clear selectedIndex
        }

        // Populate inlineSuggestion
        if let firstSuggestion = filteredSuggestions.first, showAutoComplete {
            inlineSuggestion = String(firstSuggestion.dropFirst(lastWord.count))
        } else {
            inlineSuggestion = ""
        }
    }

    private func applySuggestion(index: Int) {
        DispatchQueue.main.async {
            var words = self.text.split(separator: " ")
            _ = words.popLast()
            self.text = words.joined(separator: " ")
            self.text += self.text.isEmpty ? self.filteredSuggestions[index] : " \(self.filteredSuggestions[index])"
            self.showAutoComplete = false
            self.inlineSuggestion = ""
            self.selectedIndex = nil
        }
    }
}

#Preview {
    @State var text = ""
    let suggestions = ["apple", "banana", "orange", "grape", "watermelon"]

    return CustomTextField(
        text: $text,
        placeholderText: "Placeholder",
        autoCompleteSuggestions: suggestions,
        onEnter: { res in print(res) }
    )
}
