// HistoryDetailView.swift
import SwiftUI
import SwiftData

struct HistoryDetailView: View {
    let conversation: Conversation
    
    // Use the new AudioPlayerService for playing audio
    @StateObject private var audioPlayer = AudioPlayerService()
    // Read the user's selected voice from settings
    @AppStorage("selectedVoice") private var selectedVoice: VoiceChoice = .femaleUS
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })) { message in
                    let chatMessage = ChatMessage(
                        role: ChatMessage.Role(rawValue: message.role) ?? .assistant,
                        content: message.content,
                        timestamp: message.timestamp
                    )

                    ChatMessageView(
                        message: chatMessage,
                        onRegenerate: nil,
                        onActionTapped: nil,
                        // This closure will now call our new playAudio function
                        onPlayAudio: chatMessage.role == .assistant || chatMessage.role == .system ? {
                            playAudio(for: chatMessage)
                        } : nil
                    )
                    .id(message.id)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .navigationTitle(conversation.topic)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color("AppBackground")) // Using your design system color
        .onDisappear {
            // Stop the audio player when the user leaves the screen
            audioPlayer.stop()
        }
    }
    
    // New helper function to handle fetching and playing audio
    private func playAudio(for message: ChatMessage) {
        let cleanText = message.content
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "🎉", with: "Congratulations.")
            .replacingOccurrences(of: "• ", with: "")
            
        audioPlayer.stop()
        
        Task {
            let result = await NetworkManager.shared.fetchSpeech(for: cleanText, voice: selectedVoice)
            switch result {
            case .success(let audioData):
                await audioPlayer.play(audioData: audioData)
            case .failure(let error):
                print("❌ Failed to fetch speech audio in history: \(error.localizedDescription)")
            }
        }
    }
}
