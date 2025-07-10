import SwiftUI

struct SideBarView<SidebarContent: View, Content: View>: View {
    let sidebarContent: SidebarContent
    let mainContent: Content
    @Binding var isSidebarPresented: Bool

    init(isSidebarPresented: Binding<Bool>,
         @ViewBuilder sidebar: () -> SidebarContent,
         @ViewBuilder content: () -> Content) {
        self._isSidebarPresented = isSidebarPresented
        self.sidebarContent = sidebar()
        self.mainContent = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            mainContent
            
            if isSidebarPresented {
                // Enhanced backdrop with blur effect
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(DesignSystem.Animation.spring) {
                            isSidebarPresented = false
                        }
                    }
            }
            
            // Enhanced sidebar with modern styling
            sidebarContent
                .frame(width: UIScreen.main.bounds.width * 0.8)
                .background(
                    // Modern glassmorphism sidebar background
                    ZStack {
                        DesignSystem.Colors.cardBackground
                        
                        // Subtle gradient overlay
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.background.opacity(0.1),
                                Color.clear,
                                DesignSystem.Colors.surfaceBackground.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: isSidebarPresented ? DesignSystem.CornerRadius.large : 0
                    )
                )
                .designSystemShadow(DesignSystem.Shadows.large)
                .offset(x: isSidebarPresented ? 0 : -UIScreen.main.bounds.width)
                .animation(DesignSystem.Animation.spring, value: isSidebarPresented)
        }
        .gesture(
            DragGesture().onEnded { gesture in
                if gesture.translation.width < -100 {
                    withAnimation(DesignSystem.Animation.spring) { isSidebarPresented = false }
                } else if gesture.translation.width > 100 {
                    withAnimation(DesignSystem.Animation.spring) { isSidebarPresented = true }
                }
            }
        )
    }
}
