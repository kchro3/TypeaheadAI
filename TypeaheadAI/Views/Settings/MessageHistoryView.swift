//
//  MessageHistoryView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/17/23.
//

import Foundation
import Markdown
import SwiftUI
import CoreData

class MessageHistoryViewModel: ObservableObject {
    @Environment(\.managedObjectContext) private var viewContext
    @Published var messages: [Message] = []

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MessageEntry.createdAt, ascending: false)],
        animation: .default
    )
    private var messageEntries: FetchedResults<MessageEntry>

    private func clearHistory(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()

        do {
            let objects = try context.fetch(fetchRequest)
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            try context.save()
        } catch let error as NSError {
            // Handle the error
            print("Could not clear history: \(error), \(error.userInfo)")
        }
    }

    private func deserialize(from messageEntry: MessageEntry) -> Message {
        var attributed: AttributedOutput? = nil
        if let data = messageEntry.attributed {
            attributed = try? JSONDecoder().decode(AttributedOutput.self, from: data)
        }

        return Message(
            id: messageEntry.id!,
            createdAt: messageEntry.createdAt!,
            text: messageEntry.text!,
            attributed: attributed,
            isCurrentUser: messageEntry.isCurrentUser
        )
    }
}

struct MessageHistoryView: View {
    @StateObject var messageHistoryViewModel = MessageHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(messageHistoryViewModel.messages, id: \.id) { message in
                    MessageView(message: message) {
                        print("button press")
                        // modalManager.replyToUserMessage(incognito: incognito)
                    }
                    .padding(5)
                }
            }
        }
    }
}

struct MessageHistoryView_Previews: PreviewProvider {
    static var markdownString = """
    ```swift
    let api = ChatGPTAPI(apiKey: "API_KEY")

    Task {
        do {
            let stream = try await api.sendMessageStream(text: "What is ChatGPT?")
            for try await line in stream {
                print(line)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    ```
    """

    static let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)[0]
    }()

    static var previews: some View {
        // Create an in-memory Core Data store
        let container = NSPersistentContainer(name: "TypeaheadAI")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        let context = container.viewContext

        // Create a few sample history entries
        for i in 0..<5 {
            let entry = MessageEntry(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.text = "Text \(i)"
            entry.attributed = try? JSONEncoder().encode(AttributedOutput(string: markdownString, results: [parserResult]))
            entry.responseError = nil
            entry.isCurrentUser = (i % 2 == 0)
        }

        return MessageHistoryView()
            .environment(\.managedObjectContext, context)
    }
}
