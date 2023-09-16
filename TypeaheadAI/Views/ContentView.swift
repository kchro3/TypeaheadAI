//
//  ContentView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/16/23.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authResults):
                if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
                   let authorizationToken = appleIDCredential.authorizationCode,
                   let tokenString = String(data: authorizationToken, encoding: .utf8) {
                    print("Authorization token: \(tokenString)")
                }
            case .failure(let error):
                print("Authorisation failed: \(error.localizedDescription)")
            }
        }
        .signInWithAppleButtonStyle(.white)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
