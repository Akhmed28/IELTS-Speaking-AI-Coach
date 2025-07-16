// SpeakingPracticeView.swift (Complete corrected version)

import SwiftUI

struct SpeakingPracticeView: View {
    @ObservedObject var viewModel: SpeakingPracticeViewModel
    @Environment(\.modelContext) private var modelContext
    @Binding var isSidebarPresented: Bool
    
    // CORRECTION: Add this variable to know about the logout process
    let isCleaningUp: Bool
    
    @FocusState private var keyboardIsFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Modern background gradient
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.surfaceBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    if viewModel.isTestStarted && !viewModel.isTestComplete {
                        TestProgressBar(
                            totalSteps: viewModel.totalSteps,
                            currentStep: viewModel.currentStep
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Enhanced conversation feed with modern styling
                    ConversationFeedView(viewModel: viewModel)
                
                    // Modern bottom section with enhanced styling
                    VStack(spacing: DesignSystem.Spacing.md) {
                        if viewModel.isLoading {
                            // Show loading indicator while report is being generated
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ProgressView()
                                Text("Generating Feedback...")
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .font(.subheadline)
                            }
                        } else if viewModel.isReportAvailable {
                            // Show download button when report is ready
                            Button(action: {
                                viewModel.downloadConversation()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.title3)
                                    Text("Download Full Report")
                                        .font(DesignSystem.Typography.button)
                                }
                                .frame(maxWidth: .infinity)
                                .primaryButton()
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .sheet(item: $viewModel.reportURL) { url in
                                ShareSheet(items: [url]) 
                            }
                        } else if viewModel.isConversationPersisted && viewModel.isTestStarted {
                            // Show input field during test
                            InputBarView(viewModel: viewModel, focusedField: $keyboardIsFocused)
                        }
                    }
                    .frame(height: 90) // Give the container a fixed height to avoid UI "jumps"
                    .animation(.easeInOut, value: viewModel.isLoading)
                    .animation(.easeInOut, value: viewModel.isReportAvailable)
                }
                
                // Temporary speech error overlay
                if viewModel.showSpeechError {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Text("Could not identify your speech")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .fill(Color.gray.opacity(0.85))
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, 150) // Position higher above input area
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showSpeechError)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(), value: viewModel.isTestStarted)
            .onTapGesture {
                keyboardIsFocused = false
            }
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 50 {
                        keyboardIsFocused = false
                    }
                }
            )
            .navigationTitle("IELTS Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        keyboardIsFocused = false
                        withAnimation(DesignSystem.Animation.spring) {
                            isSidebarPresented.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .font(.title3)
                    }
                }
            }
        }
        .onChange(of: viewModel.isAiTyping) { _, isTyping in
                            // Add check: && viewModel.wasLastInputText
            if !isTyping && !viewModel.isTestComplete && viewModel.wasLastInputText && !isSidebarPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.keyboardIsFocused = true
                }
            }
        }
        .onDisappear {
            // CORRECTION: Prohibit saving data during logout
            guard !isCleaningUp else {
                print("🚫 SpeakingPracticeView: Saving skipped due to logout.")
                return
            }
            
            // Only if we're not logging out, we try to save changes.
            if viewModel.isConversationPersisted {
                viewModel.saveChanges()
            }
        }
    }
    private func hideKeyboard() {
        // Universal way to dismiss the keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - URL Extension for Identifiable
extension URL: Identifiable {
    public var id: String { absoluteString }
}
