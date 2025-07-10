// On-device Speech-to-Text using Apple's Speech Framework
import Foundation
import AVFoundation
import Speech
import Combine

/// Singleton-style observable object you can inject anywhere.
final class SpeechRecognitionService: NSObject, ObservableObject {

    // MARK: - Public outputs
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Private properties
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))! // Great for IELTS

    // MARK: - Initialisation
    override init() {
        super.init()
        // Request authorization when the service is created
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }

    // MARK: - Control
    /// Begin recording & transcribing.
    func start() throws {
        if isRecording {
            stop()
            return
        }
        
        guard authorizationStatus == .authorized else {
            print("Speech recognition not authorized.")
            // You could throw an error here to show an alert to the user
            return
        }

        // 1. Configure the audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 2. Create a new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true // Get live results

        // 3. Create the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                // Update the transcript with the best transcription
                self.transcript = result.bestTranscription.formattedString
            }

            // The task is complete if there's an error or it's the final result
            if error != nil || result?.isFinal == true {
                self.stop()
            }
        }

        // 4. Configure and start the audio engine
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    /// Stop recording gracefully.
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel() // We use cancel to stop it, not finish, to prevent final but empty results.
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
