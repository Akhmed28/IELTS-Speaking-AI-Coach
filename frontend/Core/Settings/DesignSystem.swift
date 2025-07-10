import SwiftUI

// MARK: - Design System for IELTS Practice AI
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary Colors
        static let primary = Color("Primary")
        static let primaryLight = Color("PrimaryLight")
        static let primaryDark = Color("PrimaryDark")
        
        // Secondary Colors
        static let secondary = Color("Secondary")
        static let accent = Color.accentColor
        
        // Background Colors
        static let background = Color("AppBackground")
        static let cardBackground = Color("CardBackground")
        static let surfaceBackground = Color("SurfaceBackground")
        
        // Text Colors
        static let textPrimary = Color("PrimaryTextColor")
        static let textSecondary = Color("SecondaryTextColor")
        static let textTertiary = Color.gray
        
        // Chat Colors
        static let chatUser = Color("ChatBubbleUser")
        static let chatAI = Color("ChatBubbleAI")
        static let chatSystem = Color("ChatBubbleSystem")
        
        // Status Colors
        static let success = Color("SuccessColor")
        static let warning = Color("WarningColor")
        static let error = Color("ErrorColor")
        static let info = Color("InfoColor")
        
        // UI Element Colors
        static let separator = Color("SeparatorColor")
        static let shadow = Color.black.opacity(0.1)
    }
    
    // MARK: - Typography
    struct Typography {
        // Headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // Body Text
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)
        static let bodyMedium = Font.body.weight(.medium)
        
        // Secondary Text
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.semibold)
        static let footnote = Font.footnote
        
        // Special
        static let chatMessage = Font.body
        static let button = Font.body.weight(.medium)
        static let navigationTitle = Font.headline.weight(.semibold)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: Colors.shadow, radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: Colors.shadow, radius: 4, x: 0, y: 2)
        static let large = Shadow(color: Colors.shadow, radius: 8, x: 0, y: 4)
        static let card = Shadow(color: Colors.shadow, radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Photo Settings
    struct Photo {
        static let profileImageSize: CGFloat = 100
        static let cropSize: CGFloat = 200
        static let compressionQuality: CGFloat = 0.8
        static let maxImageSize: CGFloat = 512 // Max size for storage optimization
    }
    
    struct Performance {
        static let typingAnimationDelay: Double = 0.08
        static let audioLevelUpdateInterval: Double = 0.15
        static let maxTypingUpdates: Int = 30
        static let scrollOptimizationThreshold: Int = 50
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func designSystemShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func cardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .designSystemShadow(DesignSystem.Shadows.card)
    }
    
    func primaryButton() -> some View {
        self
            .font(DesignSystem.Typography.button)
            .foregroundColor(Color.white)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.accent)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .designSystemShadow(DesignSystem.Shadows.medium)
    }
    
    func secondaryButton() -> some View {
        self
            .font(DesignSystem.Typography.button)
            .foregroundColor(DesignSystem.Colors.accent)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.accent, lineWidth: 1)
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
    }
    
    func destructiveButton() -> some View {
        self
            .font(DesignSystem.Typography.button)
            .foregroundColor(Color.white)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.error)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .designSystemShadow(DesignSystem.Shadows.medium)
    }
}
