import SwiftUI

struct InputBarView: View {
    @ObservedObject var viewModel: SpeakingPracticeViewModel
    var focusedField: FocusState<Bool>.Binding

    // Handle return key press behavior
    private func handleReturnKeyPress() {
        let trimmedText = viewModel.textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.isEmpty {
            focusedField.wrappedValue = false
        } else {
            // Submit text immediately
            viewModel.submitTextAnswer()
            // Re-enable keyboard after a very short delay
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                focusedField.wrappedValue = true
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modern separator with gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.separator.opacity(0.3),
                    DesignSystem.Colors.separator.opacity(0.6),
                    DesignSystem.Colors.separator.opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)

            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.md) {
                if viewModel.isRecording {
                    // Enhanced recording mode with modern styling
                    HStack {
                        // Modern audio wave visualization
                        AudioWaveView(isRecording: true, audioLevel: viewModel.audioLevel)
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                        
                        // Recording controls with enhanced styling
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Button(action: viewModel.cancelRecording) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(DesignSystem.Colors.error)
                                    .clipShape(Circle())
                                    .contentShape(Circle())
                            }
                            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                            
                            Button(action: viewModel.sendRecording) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(DesignSystem.Colors.accent)
                                    .clipShape(Circle())
                                    .contentShape(Circle())
                            }
                            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                        }
                    }
                } else {
                    // Enhanced text input with modern styling
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        TextField("Type your message...", text: $viewModel.textInput, axis: .vertical)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .frame(minHeight: 36)
                            .background(Color(.systemGray6))
                            .cornerRadius(18)
                            .focused(focusedField)
                            .disabled(viewModel.isAiTyping)
                            .opacity(viewModel.isAiTyping ? 0.6 : 1.0)
                            .submitLabel(.send)
                            .onSubmit(handleReturnKeyPress)
                        
                        // Action buttons container
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            // Send button (conditionally visible)
                            if !viewModel.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    viewModel.submitTextAnswer()
                                    // Re-enable keyboard quickly
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(50))
                                        focusedField.wrappedValue = true
                                    }
                                }) {
                                    Image(systemName: "arrow.up")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(DesignSystem.Colors.accent)
                                        .clipShape(Circle())
                                        .contentShape(Circle())
                                        .designSystemShadow(DesignSystem.Shadows.small)
                                }
                                .transition(.scale.combined(with: .opacity))
                                .disabled(viewModel.isAiTyping)
                            }
                            
                            // Microphone button with enhanced styling
                            Button(action: viewModel.startStopRecording) {
                                Image(systemName: "mic.fill")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .frame(width: 36, height: 36)
                                    .background(DesignSystem.Colors.cardBackground)
                                    .clipShape(Circle())
                                    .contentShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(DesignSystem.Colors.accent.opacity(0.3), lineWidth: 1)
                                    )
                                    .designSystemShadow(DesignSystem.Shadows.small)
                            }
                            .disabled(viewModel.isAiTyping)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(
                // Modern glassmorphism effect
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.cardBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(DesignSystem.Colors.separator.opacity(0.2), lineWidth: 1)
                    )
                    .designSystemShadow(DesignSystem.Shadows.medium)
                    .opacity(viewModel.isAiTyping ? 0.7 : 1.0)
            )
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)
        }
        .background(
            // Subtle background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background.opacity(0.95),
                    DesignSystem.Colors.surfaceBackground.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
