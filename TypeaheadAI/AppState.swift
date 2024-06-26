//
//  AppState.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import AudioToolbox
import Foundation
import KeyboardShortcuts
import os.log
import SwiftUI
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    // NOTE: These are needed for the Menu View
    @Published var isOnline: Bool = true
    @Published var isMenuVisible: Bool = false

    private var updateTimer: Timer?
    let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppState"
    )

    // Managers (alphabetize)
    private let appContextManager: AppContextManager
    var clientManager: ClientManager
    var conversationManager: ConversationManager
    var functionManager = FunctionManager()
    private let historyManager: HistoryManager
    @Published var intentManager: IntentManager
    @Published var quickActionManager: QuickActionManager
    @Published var modalManager: ModalManager
    @Published var onboardingWindowManager: OnboardingWindowManager
    @Published var settingsManager: SettingsManager
    var supabaseManager = SupabaseManager()

    // Actors
    private var specialPasteActor: SpecialPasteActor? = nil
    private var specialCopyActor: SpecialCopyActor? = nil
    private var specialOpenActor: SpecialOpenActor? = nil
    private var specialRecordActor: SpecialRecordActor? = nil
    private var specialVisionActor: SpecialVisionActor? = nil
    private var specialFocusActor: SpecialFocusActor? = nil

    init(
        context: NSManagedObjectContext,
        backgroundContext: NSManagedObjectContext
    ) {
        // Create local reference
        let clientManager = ClientManager()
        let modalManager = ModalManager(context: context)
        let intentManager = IntentManager(context: context, backgroundContext: backgroundContext)
        let quickActionManager = QuickActionManager(context: context, backgroundContext: backgroundContext)

        // Initialize managers (alphabetize)
        self.appContextManager = AppContextManager(clientManager: clientManager)
        self.clientManager = clientManager
        self.conversationManager = ConversationManager(context: context)
        self.historyManager = HistoryManager(context: context, backgroundContext: backgroundContext)
        self.intentManager = intentManager
        self.modalManager = modalManager
        self.quickActionManager = quickActionManager
        self.onboardingWindowManager = OnboardingWindowManager(
            context: context,
            clientManager: clientManager,
            intentManager: intentManager,
            modalManager: modalManager,
            quickActionManager: quickActionManager,
            supabaseManager: supabaseManager
        )
        self.settingsManager = SettingsManager(context: context)

        // Initialize actors
        self.specialCopyActor = SpecialCopyActor(
            intentManager: intentManager,
            historyManager: historyManager,
            clientManager: clientManager,
            quickActionManager: quickActionManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialPasteActor = SpecialPasteActor(
            historyManager: historyManager,
            quickActionManager: quickActionManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialOpenActor = SpecialOpenActor(
            intentManager: intentManager,
            clientManager: clientManager,
            quickActionManager: quickActionManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialRecordActor = SpecialRecordActor(
            appContextManager: appContextManager,
            modalManager: modalManager
        )
        self.specialVisionActor = SpecialVisionActor(
            appContextManager: appContextManager,
            modalManager: modalManager,
            clientManager: clientManager
        )
        self.specialFocusActor = SpecialFocusActor(
            appContextManager: appContextManager,
            modalManager: modalManager
        )

        // Set lazy params
        // TODO: Use a dependency injection framework or encapsulate these managers
        self.clientManager.quickActionManager = quickActionManager
        self.clientManager.appContextManager = appContextManager
        self.clientManager.intentManager = intentManager
        self.clientManager.historyManager = historyManager
        self.clientManager.supabaseManager = supabaseManager

        self.modalManager.clientManager = clientManager
        self.modalManager.conversationManager = conversationManager
        self.modalManager.functionManager = functionManager
        self.modalManager.quickActionManager = quickActionManager
        self.modalManager.settingsManager = settingsManager
        self.modalManager.specialRecordActor = specialRecordActor

        self.settingsManager.clientManager = clientManager
        self.settingsManager.quickActionManager = quickActionManager
        self.settingsManager.supabaseManager = supabaseManager

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialCopyActor?.specialCopy()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .smartCopyPerformed, object: nil)
                    }
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to smart-copy\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await specialPasteActor?.specialPaste()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .smartPastePerformed, object: nil)
                    }
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to smart-paste\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialRecord) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialRecordActor?.specialRecord()
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to smart-record\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialVision) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialVisionActor?.specialVision()
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to smart-vision\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialFocus) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialFocusActor?.specialFocus()
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to smart-focus\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatOpen) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialOpenActor?.specialOpen()
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to open chat\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatNew) { [self] in
            Task {
                do {
                    guard isOnline else {
                        return
                    }

                    try await self.specialOpenActor?.specialOpen(forceRefresh: true)
                } catch {
                    try? await clientManager.sendFeedback(feedback: "Failed to open new chat\n\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .cancelTasks) { [self] in
            guard isOnline else {
                return
            }

            self.modalManager.cancelTasks()
        }
    }
}
