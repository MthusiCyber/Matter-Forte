import Foundation
import Supabase

@MainActor
enum SupabaseConfig {
    static let redirectURL = URL(string: "matterforte://auth/callback")!

    // Keep your real project URL and client publishable (or legacy anon) key here.
    // Never embed a secret/service-role key in the app.
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://qatipvdlgcwhmcabegjl.supabase.co")!,
        supabaseKey: "sb_publishable_do7NpldwvNy-C5IPrLEUvA_pz28_hZg"
    )
}
