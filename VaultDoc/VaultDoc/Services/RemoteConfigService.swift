import Foundation

struct RemoteConfigService {

    static func fetchCategories(supabaseURL: String, supabaseKey: String) async throws -> [RemoteCategory] {
        let url = URL(string: "\(supabaseURL)/rest/v1/categories?is_active=eq.true&order=sort_order.asc")!
        return try await fetch(url: url, key: supabaseKey)
    }

    static func fetchCurrencies(supabaseURL: String, supabaseKey: String) async throws -> [RemoteCurrency] {
        let url = URL(string: "\(supabaseURL)/rest/v1/currencies?is_active=eq.true&order=code.asc")!
        return try await fetch(url: url, key: supabaseKey)
    }

    private static func fetch<T: Decodable>(url: URL, key: String) async throws -> [T] {
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RemoteConfigError.badResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([T].self, from: data)
    }
}

struct RemoteCategory: Codable, Identifiable, Hashable {
    var id: Int
    var name: String           // "jewellery"
    var displayName: String    // "Jewellery"
    var icon: String?          // SF Symbol name
    var sortOrder: Int
}

struct RemoteCurrency: Codable, Identifiable, Hashable {
    var id: Int
    var code: String           // "EUR"
    var symbol: String         // "€"
    var name: String           // "Euro"
}

enum RemoteConfigError: LocalizedError {
    case badResponse
    var errorDescription: String? { L10n.tr("config.error.load_failed") }
}

// SQL to run in Supabase SQL Editor to create the tables:
//
// create table categories (
//   id           serial primary key,
//   name         text    not null unique,
//   display_name text    not null,
//   icon         text,
//   sort_order   int     default 0,
//   is_active    boolean default true
// );
//
// insert into categories (name, display_name, icon, sort_order) values
//   ('jewellery',   'Jewellery',   'sparkles',       1),
//   ('art',         'Art',         'paintpalette',   2),
//   ('electronics', 'Electronics', 'desktopcomputer',3),
//   ('furniture',   'Furniture',   'sofa',           4),
//   ('collectibles','Collectibles','star',            5),
//   ('other',       'Other',       'archivebox',     6);
//
// create table currencies (
//   id      serial primary key,
//   code    text not null unique,
//   symbol  text not null,
//   name    text not null,
//   is_active boolean default true
// );
//
// insert into currencies (code, symbol, name) values
//   ('EUR', '€', 'Euro'),
//   ('USD', '$', 'US Dollar'),
//   ('GBP', '£', 'British Pound'),
//   ('DKK', 'kr', 'Danish Krone'),
//   ('SEK', 'kr', 'Swedish Krona'),
//   ('NOK', 'kr', 'Norwegian Krone'),
//   ('CHF', 'Fr', 'Swiss Franc'),
//   ('JPY', '¥', 'Japanese Yen');
//
// -- Public read (anon key is fine for config data)
// alter table categories enable row level security;
// create policy "public read categories" on categories for select using (true);
//
// alter table currencies enable row level security;
// create policy "public read currencies" on currencies for select using (true);
