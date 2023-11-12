//
//  SupabaseManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import AppKit
import SafariServices
import Supabase
import SwiftUI
import Foundation

class SupabaseManager: ObservableObject {
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://hwkkvezmbrlrhvipbsum.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2t2ZXptYnJscmh2aXBic3VtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTgzNjY4NTEsImV4cCI6MjAxMzk0Mjg1MX0.aDzWW0p2uI7wsVGsu1mtfvEh4my8s9zhgVTr4r008YU")
    private let callbackURL: URL = URL(string: "app.typeahead://login-callback")!

    // Use this as a flag for checking if the user is signed in.
    @Published var uuid: String?

    init() {
        // Register OAuth notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.oAuthCallback(_:)),
            name: NSNotification.Name(rawValue: "OAuthCallBack"),
            object: nil
        )
    }

    func registerWithEmail(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        let session = try await client.auth.session

        let user = session.user
        uuid = user.id.uuidString
    }

    func signinWithApple() async throws {
        let url = try client.auth.getOAuthSignInURL(provider: Provider.apple, redirectTo: callbackURL)
        NSWorkspace.shared.open(url)
    }

    func signinWithGoogle() async throws {
        let url = try client.auth.getOAuthSignInURL(provider: Provider.google, redirectTo: callbackURL)
        NSWorkspace.shared.open(url)
    }

    func signout() async throws {
        uuid = nil
        try await client.auth.signOut()
    }

    @objc func oAuthCallback(_ notification: NSNotification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        Task {
            do {
                let session = try await client.auth.session(from: url)
                let user = session.user
                DispatchQueue.main.async {
                    self.uuid = user.id.uuidString
                }
            } catch {
                print("### oAuthCallback error: \(error)")
            }
        }
    }
}
