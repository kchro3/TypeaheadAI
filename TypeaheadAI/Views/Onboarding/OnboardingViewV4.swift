//
//  OnboardingViewV4.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/11/23.
//

import SwiftUI

struct OnboardingViewV4: View {
    @ObservedObject var modalManager: ModalManager
    var settingsManager: SettingsManager
    var supabaseManager: SupabaseManager

    @State private var messages: [Message] = []
    @State private var isVisible: Bool = false
    @State private var isContinueVisible: Bool = false
    @State private var isTextEditorVisible: Bool = false
    @State private var isSignInVisible: Bool = false
    @State private var isCloseVisible: Bool = false
    @State private var onboardingStep: Int = 0
    @State private var text: String = ""

    // When streaming a result, we want to batch process tokens.
    // Since we stream tokens one at a time, we need a global variable to
    // track the token counts per batch.
    @State private var currentTextCount = 0
    private let parserThresholdTextCount = 5
    private let maxMessages = 20
    @State private var currentOutput: AttributedOutput? = nil
    private let parsingTask = ResponseParsingTask()

    @AppStorage("token3") var token: String?
    @AppStorage("settingsTab") var settingsTab: String?

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        HStack {
                            Text("TypeaheadAI").font(.title)
                        }
                        .padding()
                        .opacity(isVisible ? 1 : 0)
                        .animation(.easeIn, value: isVisible)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                                isVisible = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    modalManager.clientManager?.onboarding(
                                        onboardingStep: onboardingStep,
                                        streamHandler: self.streamHandler,
                                        completion: self.completionHandler
                                    )
                                }
                            }
                        }

                        ForEach(messages.indices, id: \.self) { index in
                            MessageView(message: messages[index])
                                .padding(5)
                        }
                    }
                    .onChange(of: messages.last) { _ in
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            HStack {
                if isSignInVisible {
                    AccountOptionButton(label: "Create an account", isAccent: true) {
                        NSApplication.shared.keyWindow?.close()
                        settingsTab = Tab.account.id
                        settingsManager.showModal()
                    }
                }

                if isTextEditorVisible {
                    VStack {
                        if #available(macOS 13.0, *) {
                            Text("Smart-paste the response here!")
                            TextEditor(text: $text)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(.primary.opacity(0.1))
                                .cornerRadius(5)
                                .lineSpacing(5)
                                .frame(maxHeight: isTextEditorVisible ? 200 : 0)
                        } else {
                            Text("Smart-paste the response here!")
                            TextEditor(text: $text)
                                .padding(10)
                                .background(.primary)
                                .cornerRadius(5)
                                .lineSpacing(5)
                                .frame(maxHeight: isTextEditorVisible ? 200 : 0)
                        }
                    }
                    .opacity(isTextEditorVisible ? 1 : 0)
                    .animation(.easeIn, value: isTextEditorVisible)
                }

                Spacer()

                if isCloseVisible {
                    Button {
                        NSApplication.shared.keyWindow?.close()
                    } label: {
                        Text("Done")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(isCloseVisible ? 1 : 0)
                    .animation(.easeIn, value: isCloseVisible)
                } else {
                    Button {
                        onboardingStep += 1
                        isContinueVisible = false
                        isTextEditorVisible = false
                        isSignInVisible = false
                        modalManager.clientManager?.onboarding(
                            onboardingStep: onboardingStep,
                            streamHandler: self.streamHandler,
                            completion: self.completionHandler
                        )
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(isContinueVisible ? 1 : 0)
                    .animation(.easeIn, value: isContinueVisible)
                }
            }
            .padding()
        }
        .background(VisualEffect().ignoresSafeArea())
    }

    /// Append text to the onboarding messages. Creates a new message if there is nothing to append to.
    func appendText(_ text: String) async {
        guard let idx = messages.indices.last, idx == onboardingStep else {
            // If the AI response doesn't exist yet, create one.
            DispatchQueue.main.async {
                messages.append(Message(id: UUID(), text: text, isCurrentUser: false))
            }
            currentTextCount = 0
            currentOutput = nil
            return
        }

        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)

        DispatchQueue.main.async {
            messages[idx].text += text
        }
        let streamText = messages[idx].text

        do {
            currentTextCount += text.count

            if currentTextCount >= parserThresholdTextCount {
                currentOutput = await parsingTask.parse(text: streamText, isDarkMode: isDarkMode)
                try Task.checkCancellation()
                currentTextCount = 0
            }

            // Check if the parser detected anything
            if let currentOutput = currentOutput, !currentOutput.results.isEmpty {
                let suffixText = streamText.trimmingPrefix(currentOutput.string)
                var results = currentOutput.results
                let lastResult = results[results.count - 1]
                var lastAttrString = lastResult.attributedString
                if case .codeBlock(_) = lastResult.parsedType,
                   let font = NSFont.preferredFont(forTextStyle: .body).apply(newTraits: .monoSpace) {
                    lastAttrString.append(
                        AttributedString(
                            String(suffixText),
                            attributes: .init([
                                .font: font,
                                .foregroundColor: NSColor.white
                            ])
                        )
                    )
                } else {
                    lastAttrString.append(AttributedString(String(suffixText)))
                }

                results[results.count - 1] = ParserResult(
                    id: UUID(),
                    attributedString: lastAttrString,
                    parsedType: lastResult.parsedType
                )

                messages[idx].attributed = AttributedOutput(string: streamText, results: results)
            } else {
                messages[idx].attributed = AttributedOutput(string: streamText, results: [
                    ParserResult(
                        id: UUID(),
                        attributedString: AttributedString(stringLiteral: streamText),
                        parsedType: .plaintext
                    )
                ])
            }
        } catch {
            messages[idx].responseError = error.localizedDescription
        }

        // Check if the parsed string is different than the full string.
        if let currentString = currentOutput?.string, currentString != streamText {
            let output = await parsingTask.parse(text: streamText, isDarkMode: isDarkMode)
            try? Task.checkCancellation()
            messages[idx].attributed = output
        }
    }

    func streamHandler(result: Result<String, Error>) {
        switch result {
        case .success(let chunk):
            Task {
                await self.appendText(chunk)
            }
        case .failure(let error as ClientManagerError):
            switch error {
            case .badRequest(let message):
                DispatchQueue.main.async {
                    self.setError(message)
                }
            default:
                DispatchQueue.main.async {
                    self.setError("Something went wrong. Please try again.")
                }
            }
        default:
            print("Unknown error")
        }
    }

    func completionHandler(result: Result<ChunkPayload, Error>) {
        switch result {
        case .success(let output):
            if let text = output.text,
               let suffix = extractAction(from: text) {
                if suffix == "delay" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        isContinueVisible = true
                    }
                } else if suffix == "show_text_field" {
                    isTextEditorVisible = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        isContinueVisible = true
                    }
                } else if suffix == "sign_in" {
                    isSignInVisible = true
                    isCloseVisible = true
                } else if suffix == "done" {
                    isCloseVisible = true
                } else {
                    isContinueVisible = true
                }
            } else {
                isContinueVisible = true
            }
        case .failure(let error):
            print(error.localizedDescription)
            self.setError(error.localizedDescription)
        }
    }

    /// Set an error message.
    func setError(_ responseError: String) {
        messages.append(Message(
            id: UUID(),
            text: "",
            isCurrentUser: false,
            responseError: responseError)
        )
    }

    func extractAction(from text: String) -> String? {
        let pattern = "\\[\\/\\/\\]: # \"(.*)\""
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let actionRange = match.range(at: 1)
            if let swiftRange = Range(actionRange, in: text) {
                return String(text[swiftRange])
            }
        }
        return nil
    }
}

#Preview {
    // Create an in-memory Core Data store
    let container = NSPersistentContainer(name: "TypeaheadAI")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    let context = container.viewContext
    return OnboardingViewV4(
        modalManager: ModalManager(),
        settingsManager: SettingsManager(context: context),
        supabaseManager: SupabaseManager()
    )
}