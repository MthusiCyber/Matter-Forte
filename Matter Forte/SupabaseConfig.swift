import Foundation
import Supabase

@MainActor
enum SupabaseConfig {
    static let redirectURL = URL(string: "matterforte://auth/callback")!
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://qatipvdlgcwhmcabegjl.supabase.co")!,
        supabaseKey: "sb_publishable_do7NpldwvNy-C5IPrLEUvA_pz28_hZg"
    )
}
