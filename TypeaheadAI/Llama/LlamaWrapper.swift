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
        Task {
            await LlamaWrapper.handler?(.success(String(cString: token)), nil)
        }
    }
}

enum LlamaWrapperError: Error {
    case serverError(_ message: String)
    case inferenceError
}

class LlamaWrapper {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LlamaWrapper"
    )

    private var cparams: llama_context_params  // context params
    private var mparams: llama_model_params    // model params
    private var model: OpaquePointer!
    private var ctx: OpaquePointer?

    static var handler: ((Result<String, Error>, AppContext?) async -> Void)?

    init(_ modelPath: URL) {
        llama_backend_init(true)
        cparams = llama_context_default_params()
        mparams = llama_model_default_params()
        model = llama_load_model_from_file(modelPath.path(), mparams)
    }

    func isLoaded() -> Bool {
        return model != nil
    }

    deinit {
        llama_free(ctx)
        llama_free_model(model)
        llama_backend_free()
    }
}

extension LlamaWrapper {
    func predict(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            LlamaWrapper.handler = { result, _ in
                switch result {
                case .success(let token): continuation.yield(token)
                case .failure: continuation.finish(throwing: LlamaWrapperError.inferenceError)
                }
            }

            Task {
                ctx = llama_new_context_with_model(model, cparams)  // NOTE: We could expose context params in the predict API?
                main_predict(ctx, prompt, 1, globalHandler)
                continuation.finish()
            }
        }
    }
}
