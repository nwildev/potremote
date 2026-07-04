import Foundation

struct PlayerStatus: Codable, Equatable {
    var connected: Bool
    var state: String?
    var positionMs: Int?
    var durationMs: Int?
    var volume: Int?
    var title: String?

    var isPlaying: Bool { state == "playing" }
    var position: TimeInterval { Double(positionMs ?? 0) / 1000 }
    var duration: TimeInterval { Double(durationMs ?? 0) / 1000 }

    static let disconnected = PlayerStatus(connected: false)
}

struct PlaylistItem: Codable, Identifiable, Equatable {
    var index: Int
    var path: String
    var name: String
    var id: Int { index }
}

struct PlaylistResponse: Codable {
    var items: [PlaylistItem]
}

enum AspectRatio: String, CaseIterable, Identifiable {
    case `default` = "default"
    case fitWindow = "fit_window"
    case r4x3 = "4_3"
    case r16x9 = "16_9"
    case r185 = "1_85"
    case r235 = "2_35"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default:   return "Исходное"
        case .fitWindow: return "В окно"
        case .r4x3:      return "4:3"
        case .r16x9:     return "16:9"
        case .r185:      return "1.85:1"
        case .r235:      return "2.35:1"
        }
    }

    var icon: String {
        switch self {
        case .default:   return "arrow.uturn.backward"
        case .fitWindow: return "arrow.up.left.and.arrow.down.right"
        case .r4x3:      return "rectangle.ratio.4.to.3"
        case .r16x9:     return "rectangle.ratio.16.to.9"
        case .r185:      return "rectangle.expand.vertical"
        case .r235:      return "pano"
        }
    }
}

func formatTime(_ t: TimeInterval) -> String {
    guard t.isFinite, t >= 0 else { return "0:00" }
    let s = Int(t)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%d:%02d", s / 60, s % 60)
}
