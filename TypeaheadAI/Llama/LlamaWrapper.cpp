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
                                        const struct llama_model * model,
                                        const std::string & text,
                                        bool   add_bos,
                                        bool   special) {
    // upper limit for the number of tokens
    int n_tokens = (int) text.length() + add_bos;
    std::vector<llama_token> result(n_tokens);
    n_tokens = llama_tokenize(model, text.data(), (int) text.length(), result.data(), (int) result.size(), add_bos, special);
    if (n_tokens < 0) {
        result.resize(-n_tokens);
        int check = llama_tokenize(model, text.data(), (int) text.length(), result.data(), (int) result.size(), add_bos, special);
    } else {
        result.resize(n_tokens);
    }
    return result;
}

/// Copied from common.cpp
std::string llama_token_to_piece(const struct llama_context * ctx, llama_token token) {
    std::vector<char> result(8, 0);
    const int n_tokens = llama_token_to_piece(llama_get_model(ctx), token, result.data(), (int) result.size());
    if (n_tokens < 0) {
        result.resize(-n_tokens);
        int check = llama_token_to_piece(llama_get_model(ctx), token, result.data(), (int) result.size());
    } else {
        result.resize(n_tokens);
    }

    return std::string(result.data(), result.size());
}

/// Copied from common.cpp
void llama_batch_clear(struct llama_batch & batch) {
    batch.n_tokens = 0;
}

/// Copied from common.cpp
void llama_batch_add(
                     struct llama_batch & batch,
                     llama_token   id,
                     llama_pos   pos,
                     const std::vector<llama_seq_id> & seq_ids,
                     bool   logits) {
    batch.token   [batch.n_tokens] = id;
    batch.pos     [batch.n_tokens] = pos;
    batch.n_seq_id[batch.n_tokens] = (int) seq_ids.size();
    for (size_t i = 0; i < seq_ids.size(); ++i) {
        batch.seq_id[batch.n_tokens][i] = seq_ids[i];
    }
    batch.logits  [batch.n_tokens] = logits;

    batch.n_tokens++;
}

/// Almost the same as simple.cpp in examples
//const char * simple_predict(struct llama_context * ctx,
//                            const char * prompt_c,
//                            const int n_threads,
//                            TokenCallback callback) {
//    std::string prompt(prompt_c);
//
//    // tokenize the prompt
//
//    printf("%s: tokenizing...\n", __func__);
//    std::vector<llama_token> tokens_list;
//    const struct llama_model * model = llama_get_model(ctx);  // Added this line
//    tokens_list = ::llama_tokenize(model, prompt, true, false);
//
//    const int max_context_size     = llama_n_ctx(ctx);
//    const int max_tokens_list_size = max_context_size - 4;
//
//    if ((int) tokens_list.size() > max_tokens_list_size) {
//        printf("%s: error: prompt too long (%d tokens, max %d)\n", __func__, (int) tokens_list.size(), max_tokens_list_size);
//        return nullptr;
//    } else {
//        printf("%s: %d tokens\n", __func__, (int) tokens_list.size());
//    }
//
//    printf("\n\n");
//
//    for (auto id : tokens_list) {
//        printf("%s", llama_token_to_piece(ctx, id).c_str());
//    }
//
//    // main loop
//
//    // The LLM keeps a contextual cache memory of previous token evaluation.
//    // Usually, once this cache is full, it is required to recompute a compressed context based on previous
//    // tokens (see "infinite text generation via context swapping" in the main example), but in this minimalist
//    // example, we will just stop the loop once this cache is full or once an end of stream is detected.
//
//    const int n_gen = max_context_size; //std::min(32, max_context_size);
//    std::string generated_text;
//
//    while (llama_get_kv_cache_token_count(ctx) < n_gen) {
//        // evaluate the transformer
//
//        if (llama_eval(ctx, tokens_list.data(), int(tokens_list.size()), llama_get_kv_cache_token_count(ctx), n_threads)) {
//            fprintf(stderr, "%s : failed to eval\n", __func__);
//            return nullptr;
//        }
//
//        tokens_list.clear();
//
//        // sample the next token
//
//        llama_token new_token_id = 0;
//
//        auto logits  = llama_get_logits(ctx);
//        auto n_vocab = llama_n_vocab(ctx);
//
//        std::vector<llama_token_data> candidates;
//        candidates.reserve(n_vocab);
//
//        for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
//            candidates.emplace_back(llama_token_data{ token_id, logits[token_id], 0.0f });
//        }
//
//        llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };
//
//        new_token_id = llama_sample_token_greedy(ctx , &candidates_p);
//
//        if (new_token_id == llama_token_eos(ctx)) {
//            break;
//        }
//
//        // callback function for the new token :
//        auto piece = llama_token_to_piece(ctx, new_token_id);
//        if (callback) {
//            callback(piece.c_str());
//        }
//
//        generated_text += piece;
//
//        // push this new token for next evaluation
//        tokens_list.push_back(new_token_id);
//    }
//
//    char* result = new char[generated_text.length() + 1];
//    std::strcpy(result, generated_text.c_str());
//    return result;
//}
//

const char * simple_predict(struct llama_context * ctx,
                            const char * prompt_c,
                            const int n_threads,
                            TokenCallback callback) {
    // total length of the sequence including the prompt
    const int n_len = 64;  // TODO: change this?

    const struct llama_model * model = llama_get_model(ctx);

    // tokenize the prompt
    std::vector<llama_token> tokens_list;
    tokens_list = ::llama_tokenize(model, prompt_c, true, false);

    const int n_ctx    = llama_n_ctx(ctx);
    const int n_kv_req = (int) (tokens_list.size() + (n_len - tokens_list.size()));

    // make sure the KV cache is big enough to hold all the prompt and generated tokens
    if (n_kv_req > n_ctx) {
        return nullptr;
    }

    // print the prompt token-by-token
    for (auto id : tokens_list) {
        printf("%s", llama_token_to_piece(ctx, id).c_str());
    }

    // create a llama_batch with size 512
    // we use this object to submit token data for decoding

    llama_batch batch = llama_batch_init(512, 0, 1);

    // evaluate the initial prompt
    for (size_t i = 0; i < tokens_list.size(); i++) {
        llama_batch_add(batch, tokens_list[i], (int) i, { 0 }, false);
    }

    // llama_decode will output logits only for the last token of the prompt
    batch.logits[batch.n_tokens - 1] = true;

    if (llama_decode(ctx, batch) != 0) {
        return nullptr;
    }

    // main loop

    int n_cur    = batch.n_tokens;
    int n_decode = 0;

    std::string generated_text;

    while (n_cur <= n_len) {
        // sample the next token
        {
            auto   n_vocab = llama_n_vocab(model);
            auto * logits  = llama_get_logits_ith(ctx, batch.n_tokens - 1);

            std::vector<llama_token_data> candidates;
            candidates.reserve(n_vocab);

            for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
                candidates.emplace_back(llama_token_data{ token_id, logits[token_id], 0.0f });
            }

            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

            // sample the most likely token
            const llama_token new_token_id = llama_sample_token_greedy(ctx, &candidates_p);

            // is it an end of stream?
            if (new_token_id == llama_token_eos(model) || n_cur == n_len) {
                break;
            }

            fflush(stdout);

            // prepare the next batch
            llama_batch_clear(batch);

            // callback function for the new token :
            auto piece = llama_token_to_piece(ctx, new_token_id);
            if (callback) {
                callback(piece.c_str());
            }

            generated_text += piece;

            // push this new token for next evaluation
            llama_batch_add(batch, new_token_id, n_cur, { 0 }, true);

            n_decode += 1;
        }

        n_cur += 1;

        // evaluate the current batch with the transformer model
        if (llama_decode(ctx, batch)) {
            fprintf(stderr, "%s : failed to eval, return code %d\n", __func__, 1);
            return nullptr;
        }
    }

    llama_print_timings(ctx);

    fprintf(stderr, "\n");

    llama_batch_free(batch);

    char* result = new char[generated_text.length() + 1];
    std::strcpy(result, generated_text.c_str());
    return result;
}
