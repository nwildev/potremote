import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    @AppStorage("server_host") var host: String = "192.168.1.100"
    @AppStorage("server_port") var port: Int = 9911
    @AppStorage("server_token") var token: String = ""

    @Published var status: PlayerStatus = .disconnected
    @Published var playlist: [PlaylistItem] = []
    @Published var lastError: String?

    /// Локальная позиция слайдера во время перетаскивания.
    @Published var scrubPosition: Double = 0
    @Published var isScrubbing = false

    private var pollingTask: Task<Void, Never>?

    var client: PotPlayerClient {
        PotPlayerClient(host: host, port: port, token: token)
    }

    // MARK: - Поллинг

    func startPolling() async {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshStatus()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func refreshStatus() async {
        do {
            let s = try await client.status()
            status = s
            lastError = nil
            if !isScrubbing {
                scrubPosition = s.position
            }
        } catch {
            status = .disconnected
            lastError = "Нет соединения с сервером"
        }
    }

    func refreshPlaylist() async {
        do {
            playlist = try await client.playlist()
            lastError = nil
        } catch {
            lastError = "Не удалось загрузить плейлист"
        }
    }

    // MARK: - Управление

    private func run(_ op: @escaping () async throws -> Void) {
        Task {
            do {
                try await op()
                lastError = nil
                await refreshStatus()
            } catch {
                lastError = "Команда не выполнена"
            }
        }
    }

    func togglePlayPause() { run { try await self.client.action("toggle") } }
    func stop()            { run { try await self.client.action("stop") } }
    func next()            { run { try await self.client.action("next") } }
    func prev()            { run { try await self.client.action("prev") } }
    func fullscreen()      { run { try await self.client.action("fullscreen") } }
    func mute()            { run { try await self.client.action("mute") } }
    func speedUp()         { run { try await self.client.action("speed_up") } }
    func speedDown()       { run { try await self.client.action("speed_down") } }
    func speedReset()      { run { try await self.client.action("speed_reset") } }

    func skip(seconds: Int) {
        run { try await self.client.seek(relativeMs: seconds * 1000) }
    }

    func commitScrub() {
        let target = Int(scrubPosition * 1000)
        isScrubbing = false
        run { try await self.client.seek(toMs: target) }
    }

    func setVolume(_ level: Double) {
        run { try await self.client.setVolume(Int(level)) }
    }

    func setAspect(_ aspect: AspectRatio) {
        run { try await self.client.setAspect(aspect) }
    }

    func playItem(_ item: PlaylistItem) {
        run { try await self.client.playPlaylistItem(index: item.index) }
    }
}
