import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var vm: PlayerViewModel
    @State private var volume: Double = 50

    private var titleText: String {
        if let t = vm.status.title, !t.isEmpty { return t }
        return "Ничего не воспроизводится"
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 24) {
                ConnectionBadge()
                Spacer()
                cover
                title
                progressSection
                transportSection
                volumeSection
                Spacer()
            }
            .padding(.top)
        }
        .onChange(of: vm.status.volume) { _, newValue in
            if let newValue { volume = Double(newValue) }
        }
    }

    // MARK: - Подвью

    private var cover: some View {
        Image(systemName: "film.stack")
            .font(.system(size: 72, weight: .light))
            .foregroundStyle(.secondary)
            .frame(width: 220, height: 220)
            .glassEffect(.regular, in: .rect(cornerRadius: 36))
    }

    private var title: some View {
        Text(titleText)
            .font(.title3.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private var progressSection: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 8) {
                Slider(
                    value: $vm.scrubPosition,
                    in: 0...max(vm.status.duration, 1),
                    onEditingChanged: { editing in
                        if editing { vm.isScrubbing = true }
                        else { vm.commitScrub() }
                    }
                )
                HStack {
                    Text(formatTime(vm.scrubPosition))
                    Spacer()
                    Text(formatTime(vm.status.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
        .padding(.horizontal)
    }

    private var transportSection: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                TransportButton(icon: "backward.end.fill") { vm.prev() }
                TransportButton(icon: "gobackward.10") { vm.skip(seconds: -10) }
                playPauseButton
                TransportButton(icon: "goforward.30") { vm.skip(seconds: 30) }
                TransportButton(icon: "forward.end.fill") { vm.next() }
            }
        }
    }

    private var playPauseButton: some View {
        Button {
            vm.togglePlayPause()
        } label: {
            Image(systemName: vm.status.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 30, weight: .bold))
                .frame(width: 76, height: 76)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.orange)
    }

    private var volumeSection: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                Slider(value: $volume, in: 0...100) { editing in
                    if !editing { vm.setVolume(volume) }
                }
                Image(systemName: "speaker.wave.3.fill")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal)
    }
}

private struct TransportButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject private var vm: PlayerViewModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.status.connected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(vm.status.connected ? "PotPlayer подключён" : (vm.lastError ?? "Нет соединения"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

struct AmbientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.07, blue: 0.16),
                Color(red: 0.16, green: 0.09, blue: 0.10),
                Color(red: 0.05, green: 0.05, blue: 0.09),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
