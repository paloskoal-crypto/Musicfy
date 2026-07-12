import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject private var audioEngine: AudioEngine
    @Environment(\.dismiss) private var dismiss

    private let freqLabels = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Preset Chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presets")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(EQPreset.all) { preset in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            audioEngine.applyPreset(preset)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.icon)
                                                .font(.system(size: 12))
                                            Text(preset.name)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .foregroundStyle(audioEngine.currentPreset == preset ? .black : .white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(audioEngine.currentPreset == preset ? Color.white : Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // EQ Band Sliders
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Custom")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal)

                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(Array(audioEngine.eqBands.enumerated()), id: \.offset) { index, band in
                                VStack(spacing: 8) {
                                    Text(gainLabel(band.gain))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(gainColor(band.gain))
                                        .frame(height: 14)

                                    // Vertical slider
                                    VerticalSlider(
                                        value: Binding(
                                            get: { Double(audioEngine.eqBands[index].gain) },
                                            set: { audioEngine.updateBandGain(at: index, gain: Float($0)) }
                                        ),
                                        range: -12...12
                                    )
                                    .frame(height: 160)

                                    Text(freqLabels[safe: index] ?? "")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.gray)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.black)
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        withAnimation { audioEngine.applyPreset(.flat) }
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private func gainLabel(_ gain: Float) -> String {
        gain == 0 ? "0" : String(format: "%+.0f", gain)
    }

    private func gainColor(_ gain: Float) -> Color {
        if gain > 6 { return .red }
        if gain > 0 { return .green }
        if gain < 0 { return .blue }
        return .gray
    }
}

// MARK: - Vertical Slider

struct VerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbY = height * (1.0 - normalized)
            let midY = height * 0.5

            ZStack(alignment: .top) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 4)
                    .frame(maxWidth: .infinity)

                // Center line (0dB)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 10, height: 1)
                    .offset(y: midY)
                    .frame(maxWidth: .infinity)

                // Active fill
                if value >= 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.7))
                        .frame(width: 4, height: max(0, midY - thumbY))
                        .offset(y: thumbY)
                        .frame(maxWidth: .infinity)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 4, height: max(0, thumbY - midY))
                        .offset(y: midY)
                        .frame(maxWidth: .infinity)
                }

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(radius: 2)
                    .offset(y: thumbY - 9)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newNorm = 1.0 - (drag.location.y / height)
                        let clamped = max(0, min(1, newNorm))
                        value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
