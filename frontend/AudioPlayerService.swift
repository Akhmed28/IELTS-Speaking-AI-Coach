// AudioPlayerService.swift (Final Version with Queueing Logic)
import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerService: ObservableObject {
    private var player: AVPlayer?
    @Published var isPlaying = false
    
    // Our new audio data queue
    private var audioQueue: [Data] = []
    
    /// Adds audio to the queue and starts playback if the player is free.
    func play(audioData: Data) {
        print("🎧 AudioPlayer LOG: Received \(audioData.count) bytes of data. Queue size: \(audioQueue.count)")
        guard !audioData.isEmpty else {
            print("⚠️ AudioPlayer LOG: Audio data is empty, cannot play.")
            return
        }
        
        // Add audio to the end of the queue
        audioQueue.append(audioData)
        
        // If nothing is playing right now, start playback
        if !isPlaying {
            playNextInQueue()
        }
    }
    
    /// Plays the next track from the queue.
    private func playNextInQueue() {
        // Make sure nothing is playing and that there's audio in the queue
        guard !isPlaying, !audioQueue.isEmpty else {
            return
        }
        
        // Take the first element from the queue
        let dataToPlay = audioQueue.removeFirst()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tts_audio.mp3")
            try dataToPlay.write(to: tempURL, options: .atomic)
            
            let playerItem = AVPlayerItem(url: tempURL)
            self.player = AVPlayer(playerItem: playerItem)
            
            // Add an observer that will trigger when the track ends
            NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
            
            player?.play()
            isPlaying = true
            print("▶️ AudioPlayer LOG: Playing next item. Items left in queue: \(audioQueue.count)")
            
        } catch {
            print("❌ AudioPlayerService: Failed to play audio. Error: \(error)")
            isPlaying = false
        }
    }
    
    /// Forcibly stops playback and clears the entire queue.
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        audioQueue.removeAll() // Clear the queue
        NotificationCenter.default.removeObserver(self)
        print("⏹️ AudioPlayer LOG: Player stopped and queue cleared.")
    }
    
    /// This method is called automatically when the audio file ends.
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        print("✅ AudioPlayer LOG: Finished playing an item.")
        // Reset the isPlaying flag and try to start the next track in the queue
        isPlaying = false
        playNextInQueue()
    }
}
