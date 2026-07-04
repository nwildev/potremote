import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var vm: PlayerViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    SectionHeader("Соотношение сторон")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AspectRatio.allCases) { aspect in
                            Button {
                                vm.setAspect(aspect)
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: aspect.icon)
                                        .font(.title3)
                                    Text(aspect.label)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 74)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.roundedRectangle(radius: 20))
                        }
                    }

                    SectionHeader("Скорость воспроизведения")
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            SpeedButton(icon: "tortoise.fill", label: "−0.1x") { vm.speedDown() }
                            SpeedButton(icon: "arrow.counterclockwise", label: "1.0x") { vm.speedReset() }
                            SpeedButton(icon: "hare.fill", label: "+0.1x") { vm.speedUp() }
                        }
                    }

                    SectionHeader("Экран и звук")
                    VStack(spacing: 12) {
                        WideActionButton(icon: "arrow.up.left.and.arrow.down.right",
                                         title: "Полный экран") { vm.fullscreen() }
                        WideActionButton(icon: "speaker.slash.fill",
                                         title: "Без звука") { vm.mute() }
                        WideActionButton(icon: "stop.fill",
                                         title: "Остановить воспроизведение") { vm.stop() }
                    }
                }
                .padding()
            }
            .background(AmbientBackground())
            .navigationTitle("Управление")
        }
    }
}

private struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

private struct SpeedButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                Text(label).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 18))
    }
}

private struct WideActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 28)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 18))
    }
}
