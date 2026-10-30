import Foundation
import Supabase

@MainActor
enum SupabaseConfig {
    static let redirectURL = URL(string: "matterforte://auth/callback")!
    // Bound network waits so a stalled connection returns control to the form.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://qatipvdlgcwhmcabegjl.supabase.co")!,
        supabaseKey: "sb_publishable_do7NpldwvNy-C5IPrLEUvA_pz28_hZg",
        options: .init(global: .init(session: session))
    )
}
