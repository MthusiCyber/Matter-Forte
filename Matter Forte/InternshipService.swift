import Foundation
import Supabase

@MainActor
enum InternshipService {
    static func load() async throws -> [InternshipRole] {
        try await SupabaseConfig.client.database.rpc("matter_forte_list_internships").execute().value
    }

    static func save(_ role: InternshipRole) async throws -> InternshipRole {
        nonisolated struct Parameters: Encodable, Sendable { let details: InternshipRole }
        return try await SupabaseConfig.client.database.rpc(
            "matter_forte_save_internship", params: Parameters(details: role)
        ).execute().value
    }
}
