//
//  LlamaWrapper.cpp
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/7/23.
//

#include "LlamaWrapper.hpp"

#include <vector>
#include <string>
#include "llama.h"

/// Copied from common.cpp
std::vector<llama_token> llama_tokenize(
                                        struct llama_context * ctx,
                                        const std::string & text,
                                        bool   add_bos) {
    // upper limit for the number of tokens
    int n_tokens = text.length() + add_bos;
    std::vector<llama_token> result(n_tokens);
    n_tokens = llama_tokenize(ctx, text.c_str(), result.data(), result.size(), add_bos);
    if (n_tokens < 0) {
        result.resize(-n_tokens);
        int check = llama_tokenize(ctx, text.c_str(), result.data(), result.size(), add_bos);
        GGML_ASSERT(check == -n_tokens);
    } else {
        result.resize(n_tokens);
    }
    return result;
}

/// Copied from common.cpp
std::string llama_token_to_piece(const struct llama_context * ctx, llama_token token) {
    std::vector<char> result(8, 0);
    const int n_tokens = llama_token_to_piece(ctx, token, result.data(), result.size());
    if (n_tokens < 0) {
        result.resize(-n_tokens);
        int check = llama_token_to_piece(ctx, token, result.data(), result.size());
        GGML_ASSERT(check == -n_tokens);
    } else {
        result.resize(n_tokens);
    }

    return std::string(result.data(), result.size());
}

/// Almost the same as simple.cpp in examples
const char * simple_predict(struct llama_context * ctx,
                            const char * prompt_c,
                            const int n_threads,
                            TokenCallback callback) {
    std::string prompt(prompt_c);

    // tokenize the prompt

    printf("%s: tokenizing...\n", __func__);
    std::vector<llama_token> tokens_list;
    tokens_list = ::llama_tokenize(ctx, prompt, true);

    const int max_context_size     = llama_n_ctx(ctx);
    const int max_tokens_list_size = max_context_size - 4;

    if ((int) tokens_list.size() > max_tokens_list_size) {
        printf("%s: error: prompt too long (%d tokens, max %d)\n", __func__, (int) tokens_list.size(), max_tokens_list_size);
        return nullptr;
    } else {
        printf("%s: %d tokens\n", __func__, (int) tokens_list.size());
    }

    printf("\n\n");

    for (auto id : tokens_list) {
        printf("%s", llama_token_to_piece(ctx, id).c_str());
    }

    // main loop

    // The LLM keeps a contextual cache memory of previous token evaluation.
    // Usually, once this cache is full, it is required to recompute a compressed context based on previous
    // tokens (see "infinite text generation via context swapping" in the main example), but in this minimalist
    // example, we will just stop the loop once this cache is full or once an end of stream is detected.

    const int n_gen = max_context_size; //std::min(32, max_context_size);
    std::string generated_text;

    while (llama_get_kv_cache_token_count(ctx) < n_gen) {
        // evaluate the transformer

        if (llama_eval(ctx, tokens_list.data(), int(tokens_list.size()), llama_get_kv_cache_token_count(ctx), n_threads)) {
            fprintf(stderr, "%s : failed to eval\n", __func__);
            return nullptr;
        }

        tokens_list.clear();

        // sample the next token

        llama_token new_token_id = 0;

        auto logits  = llama_get_logits(ctx);
        auto n_vocab = llama_n_vocab(ctx);

        std::vector<llama_token_data> candidates;
        candidates.reserve(n_vocab);

        for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
            candidates.emplace_back(llama_token_data{ token_id, logits[token_id], 0.0f });
        }

        llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

        new_token_id = llama_sample_token_greedy(ctx , &candidates_p);

        if (new_token_id == llama_token_eos(ctx)) {
            break;
        }

        // callback function for the new token :
        auto piece = llama_token_to_piece(ctx, new_token_id);
        if (callback) {
            callback(piece.c_str());
        }

        generated_text += piece;

        // push this new token for next evaluation
        tokens_list.push_back(new_token_id);
    }

    char* result = new char[generated_text.length() + 1];
    std::strcpy(result, generated_text.c_str());
    return result;
}
