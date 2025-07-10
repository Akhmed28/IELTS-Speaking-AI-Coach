import SwiftUI

struct ConversationFeedView: View {
    @ObservedObject var viewModel: SpeakingPracticeViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        Text("Loading test...")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatMessageView(
                                message: message,
                                onRegenerate: nil,
                                onActionTapped: {
                                    viewModel.disableAction(for: message.id)
                                    message.action?.perform()
                                },
                                onPlayAudio: message.role == .assistant ? {
                                    Task {
                                        await viewModel.playAudioForMessage(message)
                                    }
                                } : nil
                            )
                            .id(message.id)
                            .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .animation(.easeInOut(duration: 0.2), value: viewModel.messages.count)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessageID = viewModel.messages.last?.id {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessageID, anchor: .bottom)
                    }
                }
            }
        }
    }
}
