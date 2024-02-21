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

struct UserStatus: Codable {
    let isPremium: Bool
    let status: String?
}

class SupabaseManager: ObservableObject {
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://hwkkvezmbrlrhvipbsum.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2t2ZXptYnJscmh2aXBic3VtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTgzNjY4NTEsImV4cCI6MjAxMzk0Mjg1MX0.aDzWW0p2uI7wsVGsu1mtfvEh4my8s9zhgVTr4r008YU")
    private let callbackURL: URL = URL(string: "app.typeahead://login-callback")!

#if DEBUG
    private let apiIsPremiumURL: String = "http://localhost:8787/v4/isPremium"
#else
    private let apiIsPremiumURL: String = "https://api.typeahead.ai/v4/isPremium"
#endif

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SupabaseManager"
    )

    @Published var uuid: String?
    @Published var isPremium: Bool = false

    init() {
        Task {
            if let session = try? await client.auth.session {
                await signIn(uuid: session.user.id.uuidString)
            }
        }
    }

    func registerWithEmail(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        let session = try await client.auth.session
        await signIn(uuid: session.user.id.uuidString)
    }

    func signinWithEmail(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        await signIn(uuid: response.user.id.uuidString)
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
        isPremium = false
        try await client.auth.signOut()
    }

    func signinWithURL(from: URL) async throws {
        let session = try await client.auth.session(from: from)
        await signIn(uuid: session.user.id.uuidString)
    }

    /// Sign-in and fetch whether or not the user is a premium user
    private func signIn(uuid: String) async {
        do {
            try await checkAndSetUserStatus(uuid: uuid)
            await MainActor.run {
                self.uuid = uuid
            }
        } catch {
            await MainActor.run {
                self.uuid = nil
                self.isPremium = false
            }
        }
    }

    func checkAndSetUserStatus(uuid: String) async throws {
        guard let url = URL(string: "\(apiIsPremiumURL)?uuid=\(uuid)") else {
            throw ApiError.badRequest("Could not reach server.")
        }

        let urlRequest = URLRequest(url: url, timeoutInterval: 200)
        let (data, resp) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = resp as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ApiError.serverError("Something went wrong...")
        }

        let userStatus = try JSONDecoder().decode(UserStatus.self, from: data)
        await MainActor.run {
            self.isPremium = userStatus.isPremium
        }
    }
}
