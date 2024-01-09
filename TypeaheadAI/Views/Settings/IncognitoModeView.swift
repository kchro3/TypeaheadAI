//
//  IncognitoModeView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/5/23.
//
import SwiftUI

struct IncognitoModeView: View {
    @ObservedObject var llamaModelManager: LlamaModelManager

    @AppStorage("selectedModel") private var selectedModelURL: URL?
    @AppStorage("modelDirectory") private var directoryURL: URL?
    @State private var isPickerPresented = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var currentlyLoadingModel: URL? = nil

    init(llamaModelManager: LlamaModelManager) {
        self.llamaModelManager = llamaModelManager
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Incognito Settings").font(.title).textSelection(.enabled)

            Divider()

            Text("Sorry, this is unsupported right now. Will circle back on this later.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

struct IncognitoModeView_Previews: PreviewProvider {
    static var previews: some View {
        return IncognitoModeView(llamaModelManager: LlamaModelManager())
    }
}
