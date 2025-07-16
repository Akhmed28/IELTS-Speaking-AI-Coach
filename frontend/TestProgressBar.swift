// TestProgressBar.swift

import SwiftUI

struct TestProgressBar: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 4) {
            // Создаем сегменты для каждого шага
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 6)
                    // Анимация для плавного изменения цвета
                    .animation(.spring(), value: currentStep)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Определяет цвет сегмента в зависимости от прогресса
    private func color(for index: Int) -> Color {
        if index < currentStep {
            // Завершенные шаги
            return DesignSystem.Colors.accent
        } else if index == currentStep {
            // Активный шаг
            return DesignSystem.Colors.accent.opacity(0.6)
        } else {
            // Предстоящие шаги
            return DesignSystem.Colors.separator
        }
    }
}

// Предпросмотр для удобной разработки
#Preview {
    VStack {
        TestProgressBar(totalSteps: 10, currentStep: 0)
        TestProgressBar(totalSteps: 10, currentStep: 3)
        TestProgressBar(totalSteps: 10, currentStep: 9)
        TestProgressBar(totalSteps: 10, currentStep: 10)
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
