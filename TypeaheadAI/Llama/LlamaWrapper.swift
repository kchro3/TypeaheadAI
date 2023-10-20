//
//  LlamaWrapper.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/7/23.
//

import Foundation
import llama
import os.log

// C-friendly callback function
typealias TokenCallback = @convention(c) (UnsafePointer<CChar>?) -> Void

func globalHandler(_ token: UnsafePointer<CChar>?) {
    if let token = token {
        print("offline stream: \(token)")
        Task {
            await LlamaWrapper.handler?(.success(String(cString: token)))
        }
    }
}

enum LlamaWrapperError: Error {
    case serverError(_ message: String)
}

class LlamaWrapper {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LlamaWrapper"
    )

    private var params: llama_context_params
    private var model: OpaquePointer!
    private var ctx: OpaquePointer?

    static var handler: ((Result<String, Error>) async -> Void)?

    init(_ modelPath: URL) {
        llama_backend_init(true)
        params = llama_context_default_params()
        params.n_gpu_layers = 32
        if #available(macOS 13.0, *) {
            model = llama_load_model_from_file(modelPath.path(), params)
        } else {
            model = llama_load_model_from_file(modelPath.path, params)
        }
    }

    func isLoaded() -> Bool {
        return model != nil
    }

    func predict(
        _ prompt: String,
        handler: ((Result<String, Error>) async -> Void)? = nil
    ) async -> Result<ChunkPayload, Error> {
        if let handler = handler {
            LlamaWrapper.handler = handler
        } else {
            LlamaWrapper.handler = { _ in }
        }

        ctx = llama_new_context_with_model(model, params)
        guard let cstr = simple_predict(ctx, prompt, 1, globalHandler) else {
            return .failure(LlamaWrapperError.serverError("Failed to run simple_predict"))
        }

        let token = String(cString: cstr)
        free(UnsafeMutableRawPointer(mutating: cstr)) // Needs to be manually freed
        return .success(ChunkPayload(text: token, mode: .text, finishReason: nil))
    }

    deinit {
        llama_free(ctx)
        llama_free_model(model)
        llama_backend_free()
    }
}
