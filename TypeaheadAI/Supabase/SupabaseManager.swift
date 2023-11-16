//
//  SupabaseManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import AppKit
import Supabase
import SwiftUI
import Foundation
import os.log

class SupabaseManager: ObservableObject {
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://hwkkvezmbrlrhvipbsum.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2t2ZXptYnJscmh2aXBic3VtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTgzNjY4NTEsImV4cCI6MjAxMzk0Mjg1MX0.aDzWW0p2uI7wsVGsu1mtfvEh4my8s9zhgVTr4r008YU")
    private let callbackURL: URL = URL(string: "app.typeahead://login-callback")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SupabaseManager"
    )

    @Published var uuid: String?

    @MainActor
    func registerWithEmail(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        let session = try await client.auth.session

        let user = session.user
        uuid = user.id.uuidString
    }

    @MainActor
    func signinWithEmail(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        let user = response.user
        uuid = user.id.uuidString
        let _ = try await client.auth.session
    }

    func signinWithApple() async throws {
        let url = try client.auth.getOAuthSignInURL(provider: Provider.apple, redirectTo: callbackURL)
        NSWorkspace.shared.open(url)
    }

    func signinWithGoogle() async throws {
        let url = try client.auth.getOAuthSignInURL(provider: Provider.google, redirectTo: callbackURL)
        NSWorkspace.shared.open(url)
    }

    @MainActor
    func signout() async throws {
        uuid = nil
        try await client.auth.signOut()
    }

    @MainActor
    func signinWithURL(from: URL) async throws {
        let session = try await client.auth.session(from: from)
        let user = session.user
        self.uuid = user.id.uuidString
    }
}
