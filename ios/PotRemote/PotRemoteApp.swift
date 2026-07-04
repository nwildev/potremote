import SwiftUI

@main
struct PotRemoteApp: App {
    @StateObject private var vm = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var vm: PlayerViewModel

    var body: some View {
        TabView {
            Tab("Плеер", systemImage: "play.circle.fill") {
                NowPlayingView()
            }
            Tab("Плейлист", systemImage: "list.bullet") {
                PlaylistView()
            }
            Tab("Управление", systemImage: "slider.horizontal.3") {
                ControlsView()
            }
            Tab("Настройки", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.orange)
        .task { await vm.startPolling() }
    }
}
