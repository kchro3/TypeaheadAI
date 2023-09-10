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
        LlamaWrapper.handler?(.success(String(cString: token)))
    }
}

class LlamaWrapper {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LlamaWrapper"
    )

    private var params: llama_context_params
    private var model: OpaquePointer!
    private var ctx: OpaquePointer?

    static var handler: ((Result<String, Error>) -> Void)?

    init(_ modelPath: URL) {
        llama_backend_init(true)
        params = llama_context_default_params()
        params.n_gpu_layers = 32
        model = llama_load_model_from_file(modelPath.path(), params)
    }

    func isLoaded() -> Bool {
        return model != nil
    }

    // TODO: How to support errors
    func predict(_ prompt: String, handler: @escaping (Result<String, Error>) -> Void) {
        LlamaWrapper.handler = handler
        ctx = llama_new_context_with_model(model, params)
        _ = simple_predict(ctx, prompt, 1, globalHandler)
    }

    deinit {
        // Just in case
        llama_free(ctx)
        llama_free_model(model)
        llama_backend_free()
    }
}
