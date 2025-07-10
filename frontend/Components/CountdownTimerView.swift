// CountdownTimerView.swift
import SwiftUI

struct CountdownTimerView: View {
    let timeRemaining: Int
    let isActive: Bool
    let showPart: Bool
    let currentPart: Int
    
    init(timeRemaining: Int, isActive: Bool = true, showPart: Bool = false, currentPart: Int = 1) {
        self.timeRemaining = timeRemaining
        self.isActive = isActive
        self.showPart = showPart
        self.currentPart = currentPart
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Timer icon with animation
            Image(systemName: isActive ? "timer" : "timer.circle")
                .font(.title3)
                .foregroundColor(timerColor)
                .scaleEffect(isLowTime ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isLowTime && isActive)
            
            VStack(alignment: .leading, spacing: 2) {
                // Part indicator (optional)
                if showPart {
                    Text("Part \(currentPart)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Time display
                Text(formattedTime)
                    .font(.system(size: showPart ? 18 : 20, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(timerBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(timerBorderColor, lineWidth: isLowTime ? 2 : 1)
                )
        )
        .designSystemShadow(isLowTime ? DesignSystem.Shadows.medium : DesignSystem.Shadows.small)
        .scaleEffect(isLowTime && isActive ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isLowTime)
    }
    
    // MARK: - Computed Properties
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
    
    private var isLowTime: Bool {
        timeRemaining <= 30 && timeRemaining > 0
    }
    
    private var isCriticalTime: Bool {
        timeRemaining <= 10 && timeRemaining > 0
    }
    
    private var timerColor: Color {
        if !isActive {
            return DesignSystem.Colors.textSecondary
        } else if isCriticalTime {
            return .red
        } else if isLowTime {
            return .orange
        } else {
            return DesignSystem.Colors.accent
        }
    }
    
    private var timerBackgroundColor: Color {
        if isCriticalTime && isActive {
            return .red.opacity(0.1)
        } else if isLowTime && isActive {
            return .orange.opacity(0.1)
        } else {
            return DesignSystem.Colors.cardBackground
        }
    }
    
    private var timerBorderColor: Color {
        if isCriticalTime && isActive {
            return .red.opacity(0.3)
        } else if isLowTime && isActive {
            return .orange.opacity(0.3)
        } else {
            return DesignSystem.Colors.separator.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CountdownTimerView(timeRemaining: 300, isActive: true, showPart: true, currentPart: 1)
        CountdownTimerView(timeRemaining: 25, isActive: true, showPart: false, currentPart: 2)
        CountdownTimerView(timeRemaining: 5, isActive: true, showPart: true, currentPart: 3)
        CountdownTimerView(timeRemaining: 0, isActive: false, showPart: false, currentPart: 1)
    }
    .padding()
}
