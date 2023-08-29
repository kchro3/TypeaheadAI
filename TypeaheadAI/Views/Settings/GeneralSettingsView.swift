//
//  GeneralSettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("General Settings").font(.headline)

            Divider()

            Text("Hot-key configurations")

            Form {
                KeyboardShortcuts.Recorder("Special Copy:", name: .specialCopy)
                KeyboardShortcuts.Recorder("Special Paste:", name: .specialPaste)
            }
            .navigationTitle("Keyboard Shortcuts")

            Divider()

            Form {
                Button("Reset User Settings", action: clearUserDefaults)
            }
            .navigationTitle("General")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    private func clearUserDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
