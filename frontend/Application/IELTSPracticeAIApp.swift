import SwiftUI
import SwiftData

@main
struct IELTSPracticeAIApp: App {
    // Initialize our authentication manager as a state object so it persists throughout the app lifecycle
    @StateObject private var authManager = AuthManager()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(authManager)
                    // Force light mode for the entire app
                    .preferredColorScheme(.light)
                    // Disable auto-correction globally
                    .autocorrectionDisabled()
                
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
        }
        .modelContainer(for: [Conversation.self, Message.self])
    }
}
