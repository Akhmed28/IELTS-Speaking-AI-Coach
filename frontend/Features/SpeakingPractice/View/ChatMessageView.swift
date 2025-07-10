// ChatMessageView.swift (Финальная исправленная версия)

import SwiftUI

// Вставьте этот код в ChatMessageView.swift

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Разделяем весь текст на отдельные строки
            ForEach(text.split(separator: "\n", omittingEmptySubsequences: false), id: \.self) { line in
                let lineString = String(line)
                
                if lineString.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Создаем пустое пространство для абзацев
                    Text(" ").frame(height: 8)
                } else if lineString.hasPrefix("### ") {
                    // Обработка заголовков
                    Text(lineString.dropFirst(4))
                        .font(.headline)
                        .fontWeight(.bold)
                } else if lineString.hasPrefix("* ") {
                    // Обработка списков
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .fontWeight(.bold)
                        // Обрабатываем **жирный** текст внутри пункта списка
                        Text(parseInlineBold(from: String(line.dropFirst(2))))
                    }
                } else if lineString == "---" {
                     // Обработка разделителя
                    Divider().padding(.vertical, 4)
                } else {
                    // Обработка обычного текста с жирным начертанием
                    Text(parseInlineBold(from: lineString))
                }
            }
        }
    }
    
    /// Эта вспомогательная функция обрабатывает **жирный текст** внутри любой строки
    private func parseInlineBold(from string: String) -> AttributedString {
        if let attributedString = try? AttributedString(markdown: string) {
            return attributedString
        }
        return AttributedString(string)
    }
}

struct ChatMessageView: View {
    
//    @ObservedObject var viewModel: SpeakingPracticeViewModel?
    
    let message: ChatMessage
    let onRegenerate: (() -> Void)?
    let onActionTapped: (() -> Void)?
    let onPlayAudio: (() -> Void)?
    
    // MARK: - Body
    var body: some View {
        Group {
            if message.isUser {
                userMessageContent
            } else {
                aiMessageContent
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
    
    // MARK: - User Message
    private var userMessageContent: some View {
        HStack {
            Spacer(minLength: 60) // Этот Spacer прижимает пузырь к правому краю
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                messageContent(isUser: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.chatUser)
                    .cornerRadius(20)
                
                // Отображаем количество слов под сообщением пользователя
                Text("\(wordCount) words")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - AI Message
    private var aiMessageContent: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            aiAvatar
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    messageContent(isUser: false)
                    
                    if message.action != nil {
                        Button(action: {
                            // Просто сообщаем "наверх", что на кнопку нажали
                            onActionTapped?()
                        }) {
                            Text(message.action!.title) // Используем message.action!.title
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(DesignSystem.Colors.accent)
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if let onPlayAudio = onPlayAudio, !message.isTyping {
                        Button(action: onPlayAudio) {
                            Label("Play", systemImage: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                .background(DesignSystem.Colors.chatAI)
                .cornerRadius(20)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            Spacer(minLength: 60) // Этот Spacer не дает пузырю растягиваться на всю ширину
        }
    }
    
    // MARK: - Message Content (Главное исправление)
    private func messageContent(isUser: Bool) -> some View {
        // Вызываем наш новый, надежный обработчик
        MarkdownTextView(text: message.content)
            .font(DesignSystem.Typography.chatMessage)
            .foregroundColor(isUser ? .white : DesignSystem.Colors.textPrimary)
            .lineSpacing(5) // Увеличим интервал для лучшей читаемости
            .textSelection(.enabled)
    }
    
    private var wordCount: Int {
        message.content.split { !$0.isLetter && !$0.isNumber }.count
    }
    
    // MARK: - AI Avatar
    private var aiAvatar: some View {
        ZStack {
            Circle().fill(DesignSystem.Colors.accent)
                .frame(width: 32, height: 32)
            Image(systemName: "brain")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
