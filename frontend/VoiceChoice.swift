// VoiceChoice.swift
import Foundation
import SwiftUI

enum VoiceChoice: String, CaseIterable, Identifiable {
    case femaleUS = "female_us"
    case maleUS = "male_us"
    case femaleUK = "female_uk"
    case maleUK = "male_uk"
    case femaleAU = "female_au"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .femaleUS: "Female (American)"
        case .maleUS: "Male (American)"
        case .femaleUK: "Female (British)"
        case .maleUK: "Male (British)"
        case .femaleAU: "Female (Australian)"
        }
    }
}



struct MicButton: View {

    @StateObject private var speech = SpeechRecognitionService()

    var body: some View {
        VStack {
            Button(action: toggle) {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 36))
                    .foregroundColor(speech.isRecording ? .red : .blue)
            }

            // LIVE TEXT PREVIEW
            ScrollView {
                Text(speech.transcript)
                    .padding()
            }
            .frame(maxHeight: 200)
        }
    }

    private func toggle() {
        do {
            if speech.isRecording {
                speech.stop()
            } else {
                try speech.start()
            }
        } catch {
            // present SpeechError via alert if you like
            print(error.localizedDescription)
        }
    }
}
