//
//  LlamaWrapper.hpp
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/7/23.
//

#ifndef LlamaWrapper_hpp
#define LlamaWrapper_hpp

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Callback function per token for Swift
typedef void (*TokenCallback)(const char* token);

/// C-friendly version of simple.cpp
const char * simple_predict(struct llama_context* ctx, const char* prompt_c, const int n_threads, TokenCallback callback);

/// C-friendly version of main.cpp
int main_predict(struct llama_context* ctx,
                 const char* prompt_c,
                 const int n_threads,
                 TokenCallback callback);

#ifdef __cplusplus
}
#endif

#endif /* LlamaWrapper_hpp */
