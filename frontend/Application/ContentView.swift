// ContentView.swift (Corrected Version)

import SwiftUI
import SwiftData
import Combine

// Structure #1: Main app router
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        ZStack {
            if authManager.isValidatingSession {
                // Show a loading screen while checking for an existing session
                VStack {
                    ProgressView("Checking session...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .transition(.opacity)
                
            } else if authManager.isLoggedIn {
                // If the user is logged in, show the main app or onboarding
                if showOnboarding || !hasSeenOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                        .transition(.move(edge: .trailing))
                        .zIndex(1)
                } else {
                    MainAppView()
                        .transition(.opacity)
                }
                
            } else if let email = authManager.emailForVerification {
                // Show the verification screen if needed
                VerificationView(email: email)
                    .transition(.opacity)
                
            } else if let email = authManager.emailForPasswordReset {
                // Show the password reset screen if needed
                ResetPasswordView(email: email)
                    .transition(.opacity)
                
            } else {
                // Otherwise, show the main login/registration screen
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: authManager.isValidatingSession)
        .animation(.easeInOut(duration: 0.3), value: authManager.emailForVerification)
        .animation(.easeInOut(duration: 0.3), value: authManager.emailForPasswordReset)
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
        .onAppear {
            // When the app first appears, check if we need to show onboarding
            if authManager.isLoggedIn && !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: hasSeenOnboarding) { newValue in
            // If the user completes onboarding, hide the onboarding view
            if newValue {
                showOnboarding = false
            }
        }
    }
}

// Structure #2: Main UI after login
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var practiceViewModel = SpeakingPracticeViewModel()
    @State private var isSidebarPresented = false
    @State private var selectedTab = 0
    
    @State private var didPerformInitialSync = false
    @State private var isCleaningUp = false
    @State private var viewId = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            // --- TAB 1: AI Practice Screen ---
            // This tab uses the SideBarView to contain both the history and the main practice interface.
            SideBarView(isSidebarPresented: $isSidebarPresented) {
                // Sidebar Content: The list of past conversations
                HistoryView(
                    isTtsEnabled: practiceViewModel.isTtsEnabled,
                    onToggleTts: { isEnabled in
                        practiceViewModel.setTtsEnabled(to: isEnabled)
                    },
                    onNewChat: {
                        Task { await practiceViewModel.startNewTest() }
                        closeSidebar()
                    },
                    onSelectConversation: { conversation in
                        practiceViewModel.loadConversation(conversation)
                        closeSidebar()
                    },
                    onRenameConversation: { id, newTitle in
                        practiceViewModel.renameConversation(id: id, newTitle: newTitle)
                    },
                    onDeleteMultiple: { ids in
                        practiceViewModel.deleteMultipleConversations(ids: ids)
                    }
                )
            } content: {
                // Main Content: The chat interface for the practice session
                SpeakingPracticeView(
                    viewModel: practiceViewModel,
                    isSidebarPresented: $isSidebarPresented,
                    isCleaningUp: isCleaningUp
                )
            }
            .tabItem { Label("AI Practice", systemImage: "mic.circle.fill") }
            .tag(0)
            
            // --- TAB 2: User Profile Screen ---
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                .tag(1)
        }
        .accentColor(DesignSystem.Colors.accent)
        .id(viewId) // Used to force a full view refresh on login/logout
        .task {
            // This runs once when the view first appears
            guard !isCleaningUp else { return }
            
            practiceViewModel.setup(context: modelContext)
            
            // If no conversation is loaded, automatically start a new one.
            if practiceViewModel.messages.isEmpty {
                await practiceViewModel.startNewTest()
            }
            
            // Sync with the server in the background
            if !didPerformInitialSync {
                didPerformInitialSync = true
                Task(priority: .background) {
                    await syncWithServer()
                }
            }
        }
        .onChange(of: authManager.isLoggedIn) { isLoggedIn in
            // Clean up the view state on logout to prevent data from leaking between sessions
            if !isLoggedIn {
                isCleaningUp = true
                practiceViewModel.clearCurrentConversation()
                practiceViewModel.stopAllAudio()
                didPerformInitialSync = false
                selectedTab = 0
                isSidebarPresented = false
            } else {
                // Reset the view ID to force a complete refresh for the new user
                viewId = UUID()
                isCleaningUp = false
            }
        }
    }
    
    private func syncWithServer() async {
        guard !isCleaningUp, authManager.isLoggedIn else { return }
        
        // Upload local conversations that haven't been synced
        let idsToUpload = await practiceViewModel.fetchLocalConversationIDsForUpload()
        for id in idsToUpload {
            guard !isCleaningUp else { break }
            if let conversation = await practiceViewModel.fetchConversation(by: id) {
                await practiceViewModel.uploadConversationToServer(conversation)
            }
        }
        
        // Download conversations from the server
        guard !isCleaningUp else { return }
        if case .success(let convos) = await NetworkManager.shared.fetchConversations() {
            await practiceViewModel.mergeServerConversations(convos)
        }
    }
    
    private func closeSidebar() {
        withAnimation(.spring()) {
            isSidebarPresented = false
        }
    }
}
