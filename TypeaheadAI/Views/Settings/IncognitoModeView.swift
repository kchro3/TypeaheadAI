//
//  IncognitoModeView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/5/23.
//
import SwiftUI

struct IncognitoModeView: View {
    @ObservedObject var modelManager = LlamaModelManager()

    @AppStorage("selectedModel") private var selectedModelURL: URL?
    @AppStorage("modelDirectory") private var directoryURL: URL?
    @State private var isPickerPresented = false

    init(modelManager: LlamaModelManager = LlamaModelManager()) {
        self.modelManager = modelManager
        self.modelManager.load()
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Incognito Settings").font(.title).textSelection(.enabled)

            Divider()

            VStack(alignment: .leading) {
                Text("This is still a work in progress. Need to use a more advanced sampling method, since it's currently just doing a greedy search. Will integrate with HuggingFace in a future version, but for now, try downloading this to your model directory:")
                Link(destination: URL(string: "https://huggingface.co/TheBloke/MythoMax-L2-Kimiko-v2-13B-GGUF/blob/main/mythomax-l2-kimiko-v2-13b.Q4_K_M.gguf")!) {
                    Text("https://huggingface.co/TheBloke/MythoMax-L2-Kimiko-v2-13B-GGUF/blob/main/mythomax-l2-kimiko-v2-13b.Q4_K_M.gguf")
                        .foregroundColor(.blue)
                        .underline()
                }
            }.textSelection(.enabled)

            Divider()

            Text("In incognito mode, TypeaheadAI works without connecting to the Internet, and your copy-paste history is 100% private. We will make this more user-friendly, but you can choose which model you want to run below.")
                .textSelection(.enabled)

            Spacer()

            HStack(spacing: 3) {
                Text("Directory:").font(.headline)
                Text(directoryURL?.relativePath ?? "Not configured")
            }
            .textSelection(.enabled)

            HStack {
                Spacer()

                Button(directoryURL == nil ? "Choose folder" : "Choose different folder") {
                    isPickerPresented = true
                }
                .fileImporter(
                    isPresented: $isPickerPresented,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        directoryURL = urls.first
                        self.modelManager.load()
                    case .failure(let error):
                        print("Error selecting directory: \(error.localizedDescription)")
                    }
                }

                Button("Open in Finder") {
                    guard let directoryURL = directoryURL else {
                        return
                    }
                    NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
                }
                .disabled(directoryURL == nil)
            }

            List(modelManager.modelFiles ?? [], id: \.self) { url in
                Button(action: {
                    if selectedModelURL == url {
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
                            Image(systemName: selectedModelURL == url ? "doc.circle.fill" : "doc.circle")
                                .font(.system(size: 24))
                                .foregroundColor(selectedModelURL == url ? .blue : .primary)
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
