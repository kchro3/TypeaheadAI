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
    @Binding var suggestionSelected: Bool
    @Binding var height: CGFloat

    var onEnter: () -> Void
    var onPlainEnter: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
            if suggestionSelected {
                let newRange = NSRange(location: text.count, length: 0)
                nsView.setSelectedRange(newRange)
                suggestionSelected = false
            }
        }

        DispatchQueue.main.async {
            self.height = max(nsView.intrinsicContentSize.height, 20)
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
                    // Plain Enter pressed
                    if let index = parent.selectedIndex, index < suggestionCount {
                        parent.onEnter()
                        return true
                    } else {
                        parent.onPlainEnter()
                        return true
                    }
                }
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
            self.parent.text = textView.string
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
    let autoCompleteSuggestions: [String]

    @State private var showAutoComplete = false
    @State private var filteredSuggestions: [String] = []
    @State private var numberOfSuggestions: Int = 0
    @State private var selectedIndex: Int? = nil
    @State private var caretRect: CGRect? = nil
    @State private var suggestionSelected = false
    @State private var height: CGFloat = 20

    var body: some View {
        ZStack {
            CustomTextView(
                text: $text,
                selectedIndex: $selectedIndex,
                numberOfSuggestions: $numberOfSuggestions,
                caretRect: $caretRect,
                suggestionSelected: $suggestionSelected,
                height: $height,
                onEnter: {
                    if let index = selectedIndex {
                        applySuggestion(index: index)
                    }
                },
                onPlainEnter: {
                    print("Plain Enter pressed")  // Replace with your callback logic
                }
            )
            .onChange(of: text, perform: { value in
                filterSuggestions(input: value)
            })

            if showAutoComplete {
                GeometryReader { geometry in
                    List(filteredSuggestions.indices, id: \.self) { index in
                        Text(filteredSuggestions[index])
                            .background(index == selectedIndex ? Color.gray.opacity(0.2) : Color.clear)
                            .onTapGesture {
                                applySuggestion(index: index)
                            }
                    }
                    .frame(width: geometry.size.width, height: 100)
                    .offset(x: caretRect?.origin.x ?? 0, y: (caretRect?.origin.y ?? 0)+25)
                }
            }
        }
    }

    private func filterSuggestions(input: String) {
        let words = input.split(separator: " ")
        guard let lastWord = words.last, lastWord.count >= 3 else {
            showAutoComplete = false
            return
        }
        filteredSuggestions = autoCompleteSuggestions.filter {
            $0.lowercased().contains(lastWord.lowercased()) && $0.lowercased() != lastWord.lowercased()
        }
        numberOfSuggestions = filteredSuggestions.count
        showAutoComplete = !filteredSuggestions.isEmpty
        selectedIndex = nil
    }

    private func applySuggestion(index: Int) {
        DispatchQueue.main.async {
            var words = self.text.split(separator: " ")
            _ = words.popLast()
            self.text = words.joined(separator: " ")
            self.text += self.text.isEmpty ? self.filteredSuggestions[index] : " \(self.filteredSuggestions[index])"
            self.showAutoComplete = false
        }
    }
}

#Preview {
    @State var text = ""
    let suggestions = ["apple", "banana", "orange", "grape", "watermelon"]

    return CustomTextField(text: $text, autoCompleteSuggestions: suggestions)
}
