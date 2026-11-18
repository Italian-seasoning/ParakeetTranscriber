import Foundation

enum TranscriptionModel: String, CaseIterable, Identifiable {
    // Slider order: the default first, then the alternatives.
    case v2
    case v3
    case unified
    case nemotronEnglish = "nemotron-en"
    case whisperTurbo = "whisper-turbo"

    /// English-only Parakeet. Same ~465 MB download and speed as v3.
    static let `default`: Self = .v2

    var id: Self { self }

    var sliderPosition: Double {
        Double(Self.allCases.firstIndex(of: self) ?? 0)
    }

    static func atSliderPosition(_ value: Double) -> Self {
        guard value.isFinite else { return .default }
        let position = min(max(value, 0), Double(allCases.count - 1))
        return allCases[Int(position.rounded())]
    }

    var title: String {
        switch self {
        case .v2: "Parakeet v2"
        case .v3: "Parakeet v3"
        case .unified: "Parakeet Unified"
        case .nemotronEnglish: "Nemotron English"
        case .whisperTurbo: "Whisper Turbo"
        }
    }

    var shortCode: String {
        switch self {
        case .v2: "V2"
        case .v3: "V3"
        case .unified: "UNI"
        case .nemotronEnglish: "NEMO"
        case .whisperTurbo: "WSP"
        }
    }

    var detail: String {
        switch self {
        case .v2: "English only · Word timestamps"
        case .v3: "Multilingual"
        case .unified: "English · Readable punctuation"
        case .nemotronEnglish: "English · Streaming beta"
        case .whisperTurbo: "English · Robust, slower"
        }
    }

    /// One-time download size reported by `macparakeet-cli models list`.
    var downloadSize: String {
        switch self {
        case .v2, .v3: "465 MB"
        case .unified: "565 MB"
        case .nemotronEnglish: "600 MB"
        case .whisperTurbo: "632 MB"
        }
    }

    var menuTitle: String {
        "\(title) — \(detail)"
    }
}

enum PerformanceMode: String, CaseIterable, Identifiable {
    case efficiency
    case fullSpeed

    var id: Self { self }

    var title: String {
        switch self {
        case .efficiency: "Efficiency"
        case .fullSpeed: "Full Speed"
        }
    }

    var detail: String {
        switch self {
        case .efficiency: "Lower priority · Battery conscious"
        case .fullSpeed: "Automatic ANE, GPU, and CPU"
        }
    }
}
