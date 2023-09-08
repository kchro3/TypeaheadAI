//
//  IncognitoModeView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/5/23.
//
import SwiftUI

struct IncognitoModeView: View {
    @ObservedObject var modelManager = LlamaModelManager()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Incognito Settings").font(.title).textSelection(.enabled)

            Divider()

            Text("This is still a work in progress. I got a prototype working, but the prompts are not good enough and the library I was using was unstable.")
                .textSelection(.enabled)

            Divider()

            Text("In incognito mode, TypeaheadAI works without connecting to the Internet, and your copy-paste history is 100% private. We will make this more user-friendly, but you can choose which model you want to run below.")
                .textSelection(.enabled)

            Spacer()

            HStack(spacing: 3) {
                Text("Model files:").font(.headline)
                Text(modelManager.modelDirectoryURL?.relativePath ?? "No model directory")
            }
            .textSelection(.enabled)

            List(modelManager.modelFiles ?? [], id: \.self) { url in
                Button(action: {
                    if modelManager.selectedModel == url {
                        modelManager.unloadModel()
                    } else {
                        modelManager.isLoading = true
                        modelManager.currentlyLoadingModel = url
                        modelManager.loadModel(from: url)
                    }
                }) {
                    HStack {
                        if modelManager.isLoading && modelManager.currentlyLoadingModel == url {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.5, anchor: .center)
                                .frame(width: 24, height: 24, alignment: .center)
                        } else {
                            Image(systemName: modelManager.selectedModel == url ? "doc.circle.fill" : "doc.circle")
                                .font(.system(size: 24))
                                .foregroundColor(modelManager.selectedModel == url ? .blue : .primary)
                                .frame(width: 24, height: 24, alignment: .center)
                        }

                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 5)
                    .padding(.leading, 10)
                    .padding(.trailing, 15)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .disabled(modelManager.isLoading)
        }
        .alert(isPresented: $modelManager.showAlert) {
            Alert(title: Text("Something went wrong..."),
                  message: Text("The model failed to load."),
                  dismissButton: .default(Text("OK")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

struct IncognitoModeView_Previews: PreviewProvider {
    static var previews: some View {
        let llamaModelManager = LlamaModelManager()
        return IncognitoModeView(modelManager: llamaModelManager)
    }
}
