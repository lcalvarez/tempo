import Foundation
import Supabase

/// Singleton wrapper around the Supabase SDK.
///
/// Configuration is read from `SupabaseConfig` (a gitignored file written by
/// `scripts/bootstrap-supabase.sh`). If that file isn't present yet we fall
/// back to the local CLI defaults so the app at least builds — calls will
/// silently no-op until real credentials are wired in.
enum TempoSupabase {

    /// Shared client. Internally caches auth session in Keychain via
    /// `SupabaseClient`'s default storage.
    static let client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                db: .init(
                    encoder: jsonEncoder,
                    decoder: jsonDecoder
                )
            )
        )
    }()

    /// Encodes Swift `camelCase` properties into Postgres `snake_case` columns
    /// and uses ISO-8601 for timestamps.
    static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// Reverse of `jsonEncoder`. Drives all `.decode` calls inside PostgREST.
    static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
