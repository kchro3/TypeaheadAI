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

            VStack(alignment: .leading) {
                Text("This is still a work in progress. Need to use a more advanced sampling method, since it's currently just doing a greedy search. Will integrate with HuggingFace in a future version, but for now, try downloading this to your model directory:")
                Link(destination: URL(string: "https://huggingface.co/TheBloke/MythoMax-L2-Kimiko-v2-13B-GGUF/blob/main/mythomax-l2-kimiko-v2-13b.Q4_K_M.gguf")!) {
                    Text("https://huggingface.co/TheBloke/MythoMax-L2-Kimiko-v2-13B-GGUF/blob/main/mythomax-l2-kimiko-v2-13b.Q4_K_M.gguf")
                        .foregroundColor(.accentColor)
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
                        if let url = urls.first {
                            self.llamaModelManager.setModelDirectory(url)
                            Task {
                                do {
                                    try await self.llamaModelManager.load()
                                } catch let error {
                                    print(error.localizedDescription)
                                }
                            }
                        }
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

            List(llamaModelManager.modelFiles ?? [], id: \.self) { url in
                Button(action: {
                    if selectedModelURL == url {
                        llamaModelManager.unloadModel()
                    } else {
                        Task {
                            do {
                                isLoading = true
                                currentlyLoadingModel = url

                                try await llamaModelManager.loadModel(from: url)

                                selectedModelURL = url
                            } catch {
                                showAlert = true
                                print(error.localizedDescription)
                            }

                            isLoading = false
                            currentlyLoadingModel = nil
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
                            Image(systemName: selectedModelURL == url ? "doc.circle.fill" : "doc.circle")
                                .font(.system(size: 24))
                                .foregroundColor(selectedModelURL == url ? .accentColor : .primary)
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
                .listRowSeparator(.hidden)
            }
            .disabled(isLoading)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Something went wrong..."),
                  message: Text("The model failed to load."),
                  dismissButton: .default(Text("OK")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .onAppear {
            Task {
                do {
                    try await self.llamaModelManager.load()
                } catch let error {
                    showAlert = true
                    print(error.localizedDescription)
                }
            }
        }
    }
}

struct IncognitoModeView_Previews: PreviewProvider {
    static var previews: some View {
        return IncognitoModeView(llamaModelManager: LlamaModelManager())
    }
}
