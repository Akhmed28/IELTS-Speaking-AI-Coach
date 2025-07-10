import SwiftUI

struct AudioWaveView: View {
    @State private var animationPhase: Double = 0
    @State private var waveOffset: Double = 0
    @State private var timer: Timer?
    let isRecording: Bool
    let audioLevel: Float
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<25, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 2.5, height: waveHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.15)
                        .delay(Double(index) * 0.02),
                        value: waveOffset
                    )
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemGray6))
        )
        .onAppear {
            startWaveAnimation()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startWaveAnimation()
            } else {
                stopWaveAnimation()
            }
        }
        .onDisappear {
            stopWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        guard isRecording else { return }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                waveOffset += 0.3
            }
        }
    }
    
    private func stopWaveAnimation() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.5)) {
            waveOffset = 0
        }
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 28
        
        if !isRecording {
            return baseHeight
        }
        
        // Create multiple overlapping wave patterns for more realistic movement
        let normalizedIndex = Double(index) / 24.0
        
        // Primary wave
        let primaryWave = sin(normalizedIndex * .pi * 3 + waveOffset * 2)
        
        // Secondary wave with different frequency
        let secondaryWave = sin(normalizedIndex * .pi * 5 + waveOffset * 1.5) * 0.6
        
        // Tertiary wave for more complexity
        let tertiaryWave = sin(normalizedIndex * .pi * 7 + waveOffset * 2.5) * 0.3
        
        // Random element for natural variation
        let randomFactor = sin(waveOffset * 3 + Double(index) * 0.5) * 0.2
        
        // Combine waves
        let combinedWave = primaryWave + secondaryWave + tertiaryWave + randomFactor
        
        // Create center emphasis (middle bars are generally taller)
        let centerEmphasis = 1.0 - abs(normalizedIndex - 0.5) * 0.5
        
        // Use audio level to influence amplitude
        let audioAmplitude = max(0.3, Double(audioLevel)) // Minimum 30% amplitude
        
        // Calculate final height
        let normalizedWave = (combinedWave + 1) / 2 // Normalize to 0-1
        let height = baseHeight + (maxHeight - baseHeight) * normalizedWave * centerEmphasis * audioAmplitude
        
        return max(baseHeight, height)
    }
}

struct AudioWaveView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AudioWaveView(isRecording: true, audioLevel: 0.8)
            AudioWaveView(isRecording: false, audioLevel: 0.0)
        }
        .padding()
    }
}
