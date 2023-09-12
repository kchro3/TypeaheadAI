//
//  ProfileView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import SwiftUI
import AppKit
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isShowingMenu = false
    @State private var anchor: UnitPoint = .center
    @State private var isHovered: Bool = false

    @AppStorage("bio") private var bio: String = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MemoEntry.createdAt, ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var memoEntries: FetchedResults<MemoEntry>

    @State private var fetchLimit: Int = 10
    @State private var hasMore: Bool = true

    private let maxCharacterCount = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Profile").font(.title).textSelection(.enabled)

                Divider()

                Text("What should TypeaheadAI know about you to provide better responses?").font(.headline)

                TextEditor(text: $bio)
                    .onChange(of: bio) { newValue in
                        if newValue.count > maxCharacterCount {
                            bio = String(newValue.prefix(maxCharacterCount))
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(5)
                    .lineSpacing(5)
                    .frame(minHeight: 50, maxHeight: 200)

                Text("Character count: \(bio.count)/\(maxCharacterCount)")
                    .font(.footnote)
                    .foregroundColor(bio.count > maxCharacterCount ? .red : .primary)

                Divider()

                Text("Saved memos").font(.headline)

                ForEach(memoEntries, id: \.self) { memoEntry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Date: \(formattedDate(for: memoEntry.createdAt))")
                                .font(.footnote)
                                .foregroundColor(.primary)

                            Spacer()

                            Menu {
                                Button(action: {
                                    // Perform the deletion logic here
                                    viewContext.delete(memoEntry)

                                    // Save the changes to the managed object context
                                    do {
                                        try viewContext.save()
                                    } catch {
                                        // Handle the error, if any
                                        print("Error deleting memo entry: \(error)")
                                    }
                                }) {
                                    Text("Delete")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(.vertical, 5)
                                    .imageScale(.large)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(memoEntry.summary!)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(String(memoEntry.content!.prefix(280)))...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    private func loadMoreItems() {
        if memoEntries.count == fetchLimit {
            fetchLimit += 10
            hasMore = true
        } else {
            hasMore = false
        }
    }

    private func formattedDate(for date: Date?) -> String {
        guard let date = date else { return "N/A" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: date)
    }
}

struct ProfileView_Previews: PreviewProvider {
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
            let entry = MemoEntry(context: context)
            entry.id = UUID()
            entry.content = "Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. Content pretty long context Let's see what's a good length. \(i)"
            entry.summary = "Summary \(i)"
            entry.createdAt = Date()
        }

        return ProfileView()
            .environment(\.managedObjectContext, context)
    }
}
