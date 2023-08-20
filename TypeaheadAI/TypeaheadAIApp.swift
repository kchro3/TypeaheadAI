//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/19/23.
//

import SwiftUI

@main
struct TypeaheadAIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
