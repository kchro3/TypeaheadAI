//
//  IncognitoModeView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/5/23.
//
import SwiftUI

struct IncognitoModeView: View {
    @ObservedObject var modelManager = LlamaModelManager()
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var currentlyLoadingModel: URL?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Incognito Settings").font(.title)

            Divider()

            Text("In incognito mode, TypeaheadAI works without connecting to the Internet, and your copy-paste history is 100% private. We will make this more user-friendly, but you can choose which model you want to run below.")

            Spacer()

            HStack(spacing: 3) {
                Text("Model files:").font(.headline)
                Text(modelManager.modelDirectoryURL?.relativePath ?? "No model directory")
            }

            List(modelManager.modelFiles ?? [], id: \.self) { url in
                Button(action: {
                    if modelManager.selectedModel == url {
                        modelManager.unloadModel()
                    } else {
                        isLoading = true
                        currentlyLoadingModel = url
                        DispatchQueue.global(qos: .userInitiated).async {
                            modelManager.loadModel(from: url)
                            DispatchQueue.main.async {
                                isLoading = false
                                showAlert = true
                                currentlyLoadingModel = nil
                            }
                        }
                    }
                }) {
                    HStack {
                        if isLoading && currentlyLoadingModel == url {
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
            .disabled(isLoading)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Model Loaded"),
                  message: Text("The model has been successfully loaded."),
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
