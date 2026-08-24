import Foundation

enum TranscriptionModel: String, CaseIterable, Identifiable {
    case v3
    case v2
    case unified
    case nemotronEnglish = "nemotron-en"
    case whisperTurbo = "whisper-turbo"

    var id: Self { self }

    var title: String {
        switch self {
        case .v3: "Parakeet v3"
        case .v2: "Parakeet v2"
        case .unified: "Unified"
        case .nemotronEnglish: "Nemotron English"
        case .whisperTurbo: "Whisper Turbo"
        }
    }

    var shortCode: String {
        switch self {
        case .v3: "V3"
        case .v2: "V2"
        case .unified: "UNI"
        case .nemotronEnglish: "NEMO"
        case .whisperTurbo: "WSP"
        }
    }

    var detail: String {
        switch self {
        case .v3: "Multilingual · Fastest local default"
        case .v2: "English · Word timestamps"
        case .unified: "Readable English · Timestamps"
        case .nemotronEnglish: "English · Streaming beta"
        case .whisperTurbo: "English · Robust, slower"
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
