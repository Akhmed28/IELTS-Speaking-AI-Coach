// CueCardView.swift
import SwiftUI

struct CueCardView: View {
    let topic: Part2Topic
    let timeRemaining: Int
    let isPreparationTime: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("IELTS Speaking Part 2")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text(isPreparationTime ? "Preparation Time" : "Speaking Time")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .fontWeight(.semibold)
            }
            
            // Timer
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(timeRemaining <= 10 ? .red : DesignSystem.Colors.accent)
                Text("\(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(timeRemaining <= 10 ? .red : DesignSystem.Colors.textPrimary)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(timeRemaining <= 10 ? .red : DesignSystem.Colors.accent, lineWidth: 2)
                    )
            )
            
            // Cue Card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Topic
                Text(topic.topic)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Divider()
                    .background(DesignSystem.Colors.separator)
                
                // Instructions
                Text("You should say:")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                // Cues
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(topic.cues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Text("•")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.accent)
                                .fontWeight(.bold)
                            
                            Text(cue)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                if isPreparationTime {
                    Divider()
                        .background(DesignSystem.Colors.separator)
                    
                    Text("You have 1 minute to prepare. You can make notes if you want.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(DesignSystem.Colors.separator.opacity(0.3), lineWidth: 1)
                    )
            )
            .designSystemShadow(DesignSystem.Shadows.card)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

#Preview {
    CueCardView(
        topic: Part2Topic(
            topic: "Describe a place you have visited that you would recommend to others.",
            cues: [
                "Where it is",
                "When you visited it",
                "What you can do there",
                "And explain why you would recommend it"
            ]
        ),
        timeRemaining: 45,
        isPreparationTime: true
    )
}
