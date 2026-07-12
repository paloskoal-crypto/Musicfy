import AVFoundation

struct EQBand {
    let frequency: Float  // Hz
    let bandwidth: Float  // octaves
    var gain: Float       // dB, -24...+24
    let filterType: AVAudioUnitEQFilterType
}

struct EQPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let bands: [EQBand]

    static func == (lhs: EQPreset, rhs: EQPreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// 10-band EQ: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
extension EQPreset {

    static let flat = EQPreset(
        id: "flat", name: "Flat", icon: "slider.horizontal.3",
        bands: defaultBands(gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    )

    static let bassBoost = EQPreset(
        id: "bass_boost", name: "Bass Boost", icon: "waveform.path",
        bands: defaultBands(gains: [6, 5, 4, 2, 1, 0, 0, 0, 0, 0])
    )

    static let bassReducer = EQPreset(
        id: "bass_reducer", name: "Bass Reducer", icon: "waveform",
        bands: defaultBands(gains: [-6, -5, -4, -2, 0, 0, 0, 0, 0, 0])
    )

    static let trebleBoost = EQPreset(
        id: "treble_boost", name: "Treble Boost", icon: "chart.line.uptrend.xyaxis",
        bands: defaultBands(gains: [0, 0, 0, 0, 0, 1, 2, 3, 5, 6])
    )

    static let vocalEnhancer = EQPreset(
        id: "vocal", name: "Vocal Enhancer", icon: "mic.fill",
        bands: defaultBands(gains: [-2, -1, 0, 1, 2, 4, 5, 4, 2, 0])
    )

    static let rock = EQPreset(
        id: "rock", name: "Rock", icon: "guitars.fill",
        bands: defaultBands(gains: [5, 3, 2, -1, -2, 0, 2, 4, 5, 5])
    )

    static let pop = EQPreset(
        id: "pop", name: "Pop", icon: "music.note",
        bands: defaultBands(gains: [-2, -1, 1, 3, 4, 3, 1, -1, -2, -2])
    )

    static let jazz = EQPreset(
        id: "jazz", name: "Jazz", icon: "music.quarternote.3",
        bands: defaultBands(gains: [3, 2, 1, 2, -2, -2, 0, 1, 3, 4])
    )

    static let classical = EQPreset(
        id: "classical", name: "Classical", icon: "pianokeys",
        bands: defaultBands(gains: [4, 3, 3, 2, -1, -1, 0, 2, 3, 4])
    )

    static let electronic = EQPreset(
        id: "electronic", name: "Electronic", icon: "bolt.fill",
        bands: defaultBands(gains: [6, 5, 1, 0, -3, -2, 0, 2, 5, 6])
    )

    static let hiphop = EQPreset(
        id: "hiphop", name: "Hip-Hop", icon: "headphones",
        bands: defaultBands(gains: [6, 5, 3, 3, 1, -1, -1, 2, 3, 3])
    )

    static let lounge = EQPreset(
        id: "lounge", name: "Lounge", icon: "cup.and.saucer.fill",
        bands: defaultBands(gains: [-3, -2, 0, 2, 3, 3, 2, 1, -1, -2])
    )

    static let all: [EQPreset] = [
        .flat, .bassBoost, .bassReducer, .trebleBoost,
        .vocalEnhancer, .rock, .pop, .jazz,
        .classical, .electronic, .hiphop, .lounge
    ]

    // Frekuensi standar 10-band
    private static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    static func defaultBands(gains: [Float]) -> [EQBand] {
        zip(frequencies, gains).map { freq, gain in
            EQBand(
                frequency: freq,
                bandwidth: 1.0,
                gain: gain,
                filterType: .parametric
            )
        }
    }
}
