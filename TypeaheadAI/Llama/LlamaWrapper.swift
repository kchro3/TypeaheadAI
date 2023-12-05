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
            await LlamaWrapper.handler?(.success(String(cString: token)), nil)
        }
    }
}

func newGlobalHandler(_ token: UnsafePointer<CChar>?) {
    if let token = token {
        LlamaWrapper.newHandler?(String(cString: token))
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

    private var cparams: llama_context_params  // context params
    private var mparams: llama_model_params    // model params
    private var model: OpaquePointer!
    private var ctx: OpaquePointer?

    static var handler: ((Result<String, Error>, AppContext?) async -> Void)?
    static var newHandler: ((String) -> Void)?

    init(_ modelPath: URL) {
        llama_backend_init(true)
        cparams = llama_context_default_params()
        mparams = llama_model_default_params()
        model = llama_load_model_from_file(modelPath.path(), mparams)
    }

    func isLoaded() -> Bool {
        return model != nil
    }

    /// WIP: Keep chipping away at this.
    func main() {
        ctx = llama_new_context_with_model(model, cparams)
        main2(ctx, 1, nil)
    }

    /// Deprecated
    func predict2(
        _ prompt: String,
        handler: ((Result<String, Error>, AppContext?) async -> Void)? = nil
    ) async -> Result<ChunkPayload, Error> {
        if let handler = handler {
            LlamaWrapper.handler = handler
        } else {
            LlamaWrapper.handler = { _, _ in }
        }

        ctx = llama_new_context_with_model(model, cparams)  // NOTE: We could expose context params in the predict API?
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

extension LlamaWrapper {
    func predict(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                LlamaWrapper.newHandler = { token in
                    continuation.yield(token)
                }

                ctx = llama_new_context_with_model(model, cparams)  // NOTE: We could expose context params in the predict API?
                guard let cstr = simple_predict(
                    ctx,
                    prompt,
                    1,
                    newGlobalHandler
                ) else {
                    print("Failed to predict")
                    return
                }

                let token = String(cString: cstr)
                free(UnsafeMutableRawPointer(mutating: cstr)) // Needs to be manually freed
                print(token)
                continuation.finish()
            }
        }
    }
}
