import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject private var vm: PlayerViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.playlist.isEmpty {
                    ContentUnavailableView(
                        "Плейлист пуст",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Добавьте файлы в плейлист PotPlayer на ПК и потяните вниз для обновления.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.playlist) { item in
                                PlaylistRow(item: item,
                                            isCurrent: isCurrent(item)) {
                                    vm.playItem(item)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AmbientBackground())
            .navigationTitle("Плейлист")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.refreshPlaylist() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await vm.refreshPlaylist() }
            .task { await vm.refreshPlaylist() }
        }
    }

    private func isCurrent(_ item: PlaylistItem) -> Bool {
        guard let title = vm.status.title, !title.isEmpty else { return false }
        return item.name.localizedCaseInsensitiveContains(title)
            || title.localizedCaseInsensitiveContains(
                (item.name as NSString).deletingPathExtension)
    }
}

private struct PlaylistRow: View {
    let item: PlaylistItem
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isCurrent ? "waveform" : "play.rectangle")
                    .font(.title3)
                    .foregroundStyle(isCurrent ? .orange : .secondary)
                    .frame(width: 30)
                    .symbolEffect(.variableColor.iterative, isActive: isCurrent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.callout.weight(isCurrent ? .semibold : .regular))
                        .lineLimit(2)
                    Text(item.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(isCurrent ? .regular.tint(.orange.opacity(0.25)) : .regular,
                     in: .rect(cornerRadius: 20))
    }
}
