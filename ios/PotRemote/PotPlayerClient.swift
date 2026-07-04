import Foundation

struct PotPlayerClient {
    var host: String
    var port: Int
    var token: String

    private var base: URL? {
        URL(string: "http://\(host):\(port)")
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func request(_ path: String, method: String = "GET",
                         body: [String: Any]? = nil) async throws -> Data {
        guard let base else { throw URLError(.badURL) }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 4
        if !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: - Статус и плейлист

    func status() async throws -> PlayerStatus {
        try decoder.decode(PlayerStatus.self, from: try await request("status"))
    }

    func playlist() async throws -> [PlaylistItem] {
        try decoder.decode(PlaylistResponse.self, from: try await request("playlist")).items
    }

    // MARK: - Команды

    func action(_ name: String) async throws {
        _ = try await request(name, method: "POST")
    }

    func seek(toMs ms: Int) async throws {
        _ = try await request("seek", method: "POST", body: ["position_ms": ms])
    }

    func seek(relativeMs ms: Int) async throws {
        _ = try await request("seek", method: "POST", body: ["relative_ms": ms])
    }

    func setVolume(_ level: Int) async throws {
        _ = try await request("volume", method: "POST", body: ["level": level])
    }

    func setAspect(_ aspect: AspectRatio) async throws {
        _ = try await request("aspect", method: "POST", body: ["name": aspect.rawValue])
    }

    func playPlaylistItem(index: Int) async throws {
        _ = try await request("playlist/play", method: "POST", body: ["index": index])
    }

    func rawCommand(id: Int) async throws {
        _ = try await request("command", method: "POST", body: ["id": id])
    }
}
