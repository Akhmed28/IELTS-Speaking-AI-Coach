import Foundation
import SwiftUI
import SwiftData
import Combine
import UIKit
import AVFoundation

enum LastInputMethod {
    case text, voice
}

// MARK: - Models
struct QAPair {
    let part: Int
    let question: String
    let answer: String
}

// Add these structures at the top level of the file, before the ViewModel class
struct TestMetadata: Codable {
    let test_id: String
    let test_topic: String
    let total_parts_completed: Int
    let session_duration_estimate: TimeInterval
    let user_input_method_distribution: InputMethodDistribution
}

struct InputMethodDistribution: Codable {
    let voice: Double
    let text: Double
}

struct EnhancedFeedbackPayload: Codable {
    let conversation: [QuestionAnswerPairDTO]
    let test_metadata: TestMetadata
}

@MainActor
class SpeakingPracticeViewModel: ObservableObject {
    // MARK: - Properties
    var modelContext: ModelContext?
    
    var onConversationStarted: (() -> Void)?
    
    var wasLastInputText: Bool {
        return lastInputMethod == .text
    }
    
    @Published var messages: [ChatMessage] = []
    @Published var isRecording: Bool = false
    @Published var textInput: String = ""
    @Published var currentPart: Int = 1
    @Published var timeRemaining: Int = 0
    @Published var isTimerActive: Bool = false
    @Published var showPartTransition: Bool = false
    @Published var partTransitionText: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var isLoading: Bool = false
    @Published var retryAttempts: Int = 0
    @Published var isAwaitingPart2Start: Bool = false
    @Published var part2TopicCard: Part2Topic? = nil
    @Published var generatedReport: String? = nil
    @Published var isTestComplete: Bool = false
    @Published var isAiTyping: Bool = false
    @Published var reportURL: URL? = nil
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 0
    private var generatedReportURL: URL? = nil
    
    @Published var conversationId: Int? = nil
    @Published private(set) var isConversationPersisted = false
    @Published var isTestStarted: Bool = false
    @Published var speechErrorMessage: String = ""
    @Published var showSpeechError: Bool = false
    private var speechSubmittedSuccessfully: Bool = false
    
    @Published var isTtsEnabled: Bool = true
    @AppStorage("currentUserEmail") private var currentUserEmail: String = ""
    @AppStorage("selectedVoice") private var selectedVoice: VoiceChoice = .femaleUS
        
    
    // MARK: - Private Properties
    private var lastInputMethod: LastInputMethod = .text
//    private let speechService = SpeechRecognitionService()
    private var currentTest: IELTSTest?
    private var allTests: [IELTSTest] = []
    private var currentQuestionIndex: Int = 0
    private var timer: Timer?
    private var originalTypedText: String = ""
    private var newTestCreationTask: Task<Void, Never>?
    private var currentQuestion: String = ""
    private let maxRetryAttempts = 3
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var conversationHistoryForFeedback: [QAPair] = []
//    private let ttsService = TextToSpeechService()
    private var isSetupCompleted = false // Flag to prevent multiple setups
    private var audioLevelTimer: Timer?
    private var currentConversationID: UUID?
    private var isCleaningUp = false
    private var activeTasks: [Task<Void, Never>] = []
    
    // MARK: - Constants
    private let part1Duration = 300 // 5 minutes
    private let part2PrepTime = 60   // 1 minute prep time
    private let part2SpeakTime = 120 // 2 minutes speaking
    private let part3Duration = 300  // 5 minutes
    private let audioPlayer = AudioPlayerService()
    // In SpeakingPracticeViewModel.swift

    // Use the new service we created
    private let speechRecognitionService = SpeechRecognitionService()
    // To hold our Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    var isReportAvailable: Bool { generatedReportURL != nil }
    
    // MARK: - Initialization
    init() {
        self.isTtsEnabled = UserDefaults.standard.object(forKey: "isTtsEnabled") as? Bool ?? true
        loadTestsFromJSON()
        // speechService.requestAuthorization() // <-- Удалите эту строку. Сервис запрашивает разрешение при инициализации.

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLogout),
            name: AuthManager.userDidLogoutNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    // Эта функция будет нашим новым обработчиком для Toggle
    func setTtsEnabled(to isEnabled: Bool) {
        self.isTtsEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "isTtsEnabled")

        // This is the crucial part that was likely missing.
        // If the toggle is turned OFF, we immediately stop the audio.
        if !isEnabled {
            stopVoice()
        }
    }
    
    func disableAction(for messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].action = nil
        }
    }
    
    // SpeakingPracticeViewModel.swift

    func setup(context: ModelContext) {
        // Проверка на многократную настройку остается
        if self.modelContext !== context || !isSetupCompleted {
            self.modelContext = context
            isSetupCompleted = true

            // --- НАЧАЛО ИСПРАВЛЕНИЯ ---

            // 1. Подписываемся на свойство `$transcript` сервиса и напрямую
            //    присваиваем его значение свойству `textInput` нашего ViewModel.
            //    Теперь текст из распознавания речи будет автоматически появляться в текстовом поле.
            speechRecognitionService.$transcript
                .receive(on: DispatchQueue.main)
                .assign(to: \.textInput, on: self)
                .store(in: &cancellables)

            // 2. Подписываемся на состояние записи, чтобы UI обновлялся корректно.
            speechRecognitionService.$isRecording
                .receive(on: DispatchQueue.main)
                .assign(to: \.isRecording, on: self)
                .store(in: &cancellables)

            // 3. Удаляем подписку на `$error` и `$finalTranscription`, так как их нет в сервисе.

            // --- КОНЕЦ ИСПРАВЛЕНИЯ ---
        }
    }
    
    func stopVoice() {
        audioPlayer.stop()
    }
    
    // In SpeakingPracticeViewModel.swift

    /// Stops any ongoing text-to-speech audio playback.
    func stopAllAudio() {
        print("🔈 AudioPlayer: Stop command received from ViewModel.")
        // Assuming your AudioPlayerService instance is named 'audioPlayer'
        audioPlayer.stop()
    }
    
    func clearCurrentConversation() {
        print("🧹 SpeakingPracticeViewModel: Запуск полной очистки состояния...")
        isCleaningUp = true
        
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
        
        stopTimer()
        stopAudioLevelMonitoring()
        speechRecognitionService.stop()
        audioPlayer.stop() // Correctly stops the new audio player
        
        messages.removeAll()
        conversationHistoryForFeedback.removeAll()
        isTestStarted = false
        isTestComplete = false
        isConversationPersisted = false
        reportURL = nil
        generatedReportURL = nil
        isAiTyping = false
        isLoading = false
        isRecording = false
        textInput = ""
        originalTypedText = ""
        currentConversationID = nil
        currentTest = nil
        
        isCleaningUp = false
        print("✅ SpeakingPracticeViewModel: Очистка состояния завершена.")
    }
    
    @MainActor
    func startNewTest() async {
        clearCurrentConversation()
        print("🚀 SpeakingPracticeViewModel: Запуск нового теста...")
        currentTest = allTests.randomElement()
        
        // 👇 ИСПРАВЬТЕ ЭТУ СТРОКУ
        let startAction = ChatAction(title: "Start", perform: { [weak self] in self?.startPart1() })
        
        await streamMessage("Welcome to your IELTS Speaking Test! Click 'Start' when you're ready to begin.", role: .system, action: startAction)
    }
    
    func loadConversation(_ conversation: Conversation) {
        clearCurrentConversation()
        isConversationPersisted = true
        currentConversationID = conversation.id
        
        var lastQuestion = ""
        
        for message in conversation.messages {
            let role = ChatMessage.Role(rawValue: message.role) ?? .system
            messages.append(ChatMessage(role: role, content: message.content, timestamp: message.timestamp))
            
            if role == .assistant && !message.content.contains("**") && !message.content.contains("Part") {
                lastQuestion = message.content
            } else if role == .user && message.content != "Start" && !lastQuestion.isEmpty {
                let messageIndex = conversation.messages.firstIndex(of: message) ?? 0
                let totalMessages = conversation.messages.count
                let part = messageIndex < totalMessages / 3 ? 1 : (messageIndex < 2 * totalMessages / 3 ? 2 : 3)
                conversationHistoryForFeedback.append(
                    QAPair(part: part, question: lastQuestion, answer: message.content)
                )
            }
        }
        
        isTestStarted = !conversation.messages.isEmpty
        if conversation.isComplete {
            isTestComplete = true
            generateDownloadFile()
        }
    }
    
    func saveChanges() {
        guard let context = modelContext, !isCleaningUp else { return }
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    
    func deleteConversation(_ conversation: Conversation) {
        guard let context = modelContext else { return }
        
        if let serverId = conversation.serverId {
            Conversation.markAsDeleted(serverId: serverId)
            Task {
                _ = await NetworkManager.shared.deleteBackendConversation(serverId: serverId)
            }
        }
        
        Task {
            await MainActor.run {
                context.delete(conversation)
                saveChanges()
                if currentConversationID == conversation.id {
                    currentConversationID = nil
                }
            }
        }
    }
    
    func deleteMultipleConversations(ids: Set<UUID>) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate<Conversation> { conversation in
                ids.contains(conversation.id)
            }
        )
        
        Task {
            await MainActor.run {
                // Safe fetch with error handling
                for attempt in 1...3 {
                    do {
                        let conversationsToDelete = try context.fetch(descriptor)
                        for conversation in conversationsToDelete {
                            if let serverId = conversation.serverId {
                                Conversation.markAsDeleted(serverId: serverId)
                                Task {
                                    _ = await NetworkManager.shared.deleteBackendConversation(serverId: serverId)
                                }
                            }
                            context.delete(conversation)
                        }
                        saveChanges()
                        return
                    } catch {
                        print("❌ Попытка \(attempt) массового удаления диалогов неудачна: \(error)")
                        if attempt == 3 {
                            print("⚠️ Не удалось удалить диалоги после 3 попыток")
                        } else {
                            Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                        }
                    }
                }
            }
        }
    }

    func regenerateLastResponse() {
        guard let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }) else { return }
        messages.remove(at: lastAssistantIndex)
        
        Task {
            await streamMessage(currentQuestion, role: .assistant)
        }
    }
    
    // In SpeakingPracticeViewModel.swift

    func playAudioForMessage(_ message: ChatMessage) async {
        guard isTtsEnabled else { return }

        let cleanText = message.content
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "🎉", with: "Congratulations.")
            .replacingOccurrences(of: "• ", with: "")
        
        // Don't call stopVoice() here - let the queue handle multiple audio requests
        
        let result = await NetworkManager.shared.fetchSpeech(for: cleanText, voice: selectedVoice)
        switch result {
        case .success(let audioData):
            await audioPlayer.play(audioData: audioData)
            
            // Wait for this audio to complete before returning
            await waitForAudioToComplete()
            
        case .failure(let error):
            print("❌ Failed to fetch speech audio: \(error.localizedDescription)")
        }
    }
    
    /// Waits for the current audio to finish playing
    private func waitForAudioToComplete() async {
        while audioPlayer.isPlaying {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    
    @objc private func handleLogout() {
        // Call the existing function to stop the audio player
        self.stopAllAudio()
    }
    
    // MARK: - Input Handling Methods
    
//    private func waitForTTSToComplete() async {
//        while ttsService.isSpeaking {
//            try? await Task.sleep(for: .milliseconds(100))
//        }
//    }
    
    // In SpeakingPracticeViewModel.swift

    // This is the new, correct version of the function
    private func handleTranscribedText(_ text: String) {
        let transcribedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcribedText.isEmpty else { return }

        // Set the last input method to voice
        lastInputMethod = .voice

        // Adds the user's message to the chat
        let userMessage = ChatMessage(role: .user, content: transcribedText)
        messages.append(userMessage)

        // Saves the message to your database
        if let conversation = getCurrentConversation(), isConversationPersisted {
            let dbMessage = Message(content: transcribedText, role: "user", timestamp: Date())
            conversation.messages.append(dbMessage)
            saveChanges()
        }

        // And finally, calls the main logic handler to get the next question
        handleUserResponse(transcribedText)
    }
    
    private func showTemporarySpeechError(_ message: String) {
        speechErrorMessage = message
        showSpeechError = true
        
        // Auto-hide after 3 seconds
        Task {
            try await Task.sleep(for: .seconds(3))
            await MainActor.run {
                showSpeechError = false
            }
        }
    }
    
    func submitTextAnswer() {
        // Устанавливаем, что последний метод ввода - ТЕКСТ
        lastInputMethod = .text
        
        let trimmedText = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let userMessage = ChatMessage(role: .user, content: trimmedText)
        messages.append(userMessage)
        
        if let conversation = getCurrentConversation(), isConversationPersisted {
            let dbMessage = Message(content: trimmedText, role: "user", timestamp: Date())
            conversation.messages.append(dbMessage)
            saveChanges()
        }
        
        textInput = ""
        handleUserResponse(trimmedText)
    }
    
    func startStopRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording()
            }
        }
    }
    
    func cancelRecording() {
        stopRecording()
        // Восстанавливаем текст, который был в поле до начала записи
        textInput = originalTypedText
        originalTypedText = ""
    }
    
    func sendRecording() {
        lastInputMethod = .voice
        
        // Сначала останавливаем запись, чтобы зафиксировать финальный текст
        stopRecording()
        
        let textToSend = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Если есть какой-то текст, отправляем его
        if !textToSend.isEmpty {
            submitTextAnswer() // Используем submitTextAnswer для отправки
        } else {
            showTemporarySpeechError("🎤 No speech was transcribed to send.")
        }
        
        // Очищаем временные переменные
        originalTypedText = ""
    }
    
    // MARK: - Server Synchronization Logic

    func fetchLocalConversationIDsForUpload() async -> [UUID] {
        guard !isCleaningUp, !currentUserEmail.isEmpty else { return [] }
        let email = self.currentUserEmail
        guard let context = self.modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate<Conversation> { conversation in
                conversation.serverId == nil && conversation.isComplete == true && conversation.userEmail == email
            }
        )
        do {
            return try context.fetch(descriptor).map { $0.id }
        } catch {
            print("❌ Не удалось получить ID диалогов для выгрузки: \(error)")
            return []
        }
    }

    func fetchConversation(by id: UUID) async -> Conversation? {
        guard !isCleaningUp else { return nil }
        guard let context = self.modelContext else { return nil }
        
        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    func uploadConversationToServer(_ conversation: Conversation) async {
        guard !isCleaningUp else { return }
        
        let sortedMessages = conversation.messages.sorted(by: { $0.timestamp < $1.timestamp })
        var qaPairs: [QuestionAnswerPairDTO] = []
        var currentQuestion = ""
        for message in sortedMessages {
            if message.role == "assistant" || message.role == "system" {
                currentQuestion = message.content
            } else if message.role == "user" && !currentQuestion.isEmpty {
                qaPairs.append(QuestionAnswerPairDTO(
                    question: currentQuestion, answer: message.content, part: 1, topic: conversation.topic,
                    answerLength: message.content.count, responseTime: nil
                ))
                currentQuestion = ""
            }
        }
        
        if qaPairs.isEmpty { return }
        
        let payload = ConversationPayload(conversation: qaPairs)
        let result = await NetworkManager.shared.saveConversation(payload)
            
        if case .success(let savedConversation) = result, !isCleaningUp {
            await updateConversationWithServerId(conversation.id, serverId: savedConversation.id)
        }
    }
        
    func updateConversationWithServerId(_ localId: UUID, serverId: Int) async {
        guard let context = self.modelContext else { return }
        if let freshConversation = await self.fetchConversation(by: localId) {
            freshConversation.serverId = serverId
            do {
                try context.save()
                print("✅ Локальный диалог выгружен на сервер с ID: \(serverId)")
            } catch {
                print("❌ Ошибка сохранения serverId: \(error)")
            }
        }
    }

    func mergeServerConversations(_ serverConversations: [ConversationDTO]) async {
        guard !serverConversations.isEmpty, !isCleaningUp, let context = self.modelContext else { return }
        
        let formatter = ISO8601DateFormatter()
        let deletedIDs = Conversation.deletedServerIDs
        let userEmail = self.currentUserEmail
        guard !userEmail.isEmpty else { return }
        
        do {
            for serverConvo in serverConversations {
                guard !isCleaningUp else { break }
                let serverId = serverConvo.id
                if deletedIDs.contains(serverId) { continue }
                
                let predicate = #Predicate<Conversation> { $0.serverId == serverId }
                var fetchDescriptor = FetchDescriptor<Conversation>(predicate: predicate)
                fetchDescriptor.fetchLimit = 1
                if let existing = try? context.fetch(fetchDescriptor), !existing.isEmpty { continue }
                
                guard !serverConvo.conversation.isEmpty else { continue }
                
                let topic = "Synced: \(serverConvo.conversation.first?.question.prefix(50) ?? "Session")"
                let startDate = formatter.date(from: serverConvo.created_at) ?? Date()

                let newLocalConvo = Conversation(startDate: startDate, topic: topic, userEmail: userEmail)
                newLocalConvo.serverId = serverId
                newLocalConvo.isComplete = true
                
                for pair in serverConvo.conversation {
                    newLocalConvo.messages.append(Message(content: pair.question, role: "assistant", timestamp: Date()))
                    newLocalConvo.messages.append(Message(content: pair.answer, role: "user", timestamp: Date()))
                }
                context.insert(newLocalConvo)
            }
            try context.save()
            print("✅ Синхронизация завершена. Локальная база данных обновлена.")
        } catch {
            print("❌ Ошибка сохранения синхронизированных данных: \(error)")
        }
    }
    
    // MARK: - Private Methods
    private func loadTestsFromJSON() {
        guard let url = Bundle.main.url(forResource: "IELTSTests", withExtension: "json") else {
            print("Error: IELTSTests.json file not found.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            allTests = try JSONDecoder().decode([IELTSTest].self, from: data)
            print("Successfully loaded \(allTests.count) tests from JSON.")
        } catch {
            print("Error decoding IELTSTests.json: \(error)")
        }
    }
    
    private func setupAudioLevelMonitoring() {
        // Don't start timer immediately - only when recording starts
    }
    
    private func startAudioLevelMonitoring() {
        stopAudioLevelMonitoring()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            let time = Date().timeIntervalSince1970
            let baseLevel = sin(time * 2) * 0.3 + 0.5
            let variation = sin(time * 8) * 0.2
            let randomNoise = Float.random(in: -0.1...0.1)
            let level = Float(baseLevel + variation) + randomNoise
            self.audioLevel = max(0.1, min(1.0, level))
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    /// Helper to remove markdown formatting from text
    private func cleanMessageText(_ text: String) -> String {
        var cleaned = text
        let markdownPatterns = [
            "\\*\\*", // bold
            "\\#\\#?+", // headings
            "\\* ", // bullet points
            "- ", // dashes
            "> ", // blockquotes
            "_", // italics/underline
            "`", // code
        ]
        for pattern in markdownPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        // Remove extra whitespace and newlines
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func streamMessage(_ fullText: String, role: ChatMessage.Role, action: ChatAction? = nil, withAnimation: Bool = true) async -> ChatMessage? {
        guard !isCleaningUp else { return nil }
        isAiTyping = true
        
        let chatMessage = ChatMessage(role: role, content: "", isTyping: true, action: action)
        messages.append(chatMessage)
        
        guard let messageIndex = messages.lastIndex(where: { $0.id == chatMessage.id }) else {
            isAiTyping = false
            return nil
        }
        
        do {
            if withAnimation {
                // Optimize streaming speed based on message length
                let characters = Array(fullText)
                let streamDelay: Double = characters.count > 100 ? 10 : 5 // Faster for shorter messages
                
                // Stream in chunks for better performance
                let chunkSize = 3
                var currentIndex = 0
                
                while currentIndex < characters.count {
                    try Task.checkCancellation()
                    guard messages.indices.contains(messageIndex) else { throw CancellationError() }
                    
                    let endIndex = min(currentIndex + chunkSize, characters.count)
                    let chunk = characters[currentIndex..<endIndex]
                    messages[messageIndex].content.append(contentsOf: chunk)
                    
                    try await Task.sleep(for: .milliseconds(streamDelay))
                    currentIndex += chunkSize
                }
            } else {
                guard messages.indices.contains(messageIndex) else { throw CancellationError() }
                messages[messageIndex].content = fullText
            }
            
            guard messages.indices.contains(messageIndex) else { throw CancellationError() }
            messages[messageIndex].isTyping = false
            
            // Save message to database asynchronously
            if let conversation = getCurrentConversation(), isConversationPersisted {
                Task {
                    let dbMessage = Message(content: fullText, role: role.rawValue, timestamp: Date())
                    conversation.messages.append(dbMessage)
                    saveChanges()
                }
            }

            // Play audio only if needed and not during test completion
            if isTtsEnabled && (role == .assistant || role == .system) && !isTestComplete {
                await playAudioForMessage(messages[messageIndex])
            }
            
            isAiTyping = false
            return chatMessage
            
        } catch {
            print("❌ Message streaming cancelled or failed: \(error)")
            if messages.indices.contains(messageIndex) {
                messages[messageIndex].isTyping = false
            }
            isAiTyping = false
            return nil
        }
    }

    private func resetTestState() {
        print("🔄 Resetting test state")
        currentPart = 1
        currentQuestionIndex = 0
        timeRemaining = 0
        isTimerActive = false
        showPartTransition = false
        isAwaitingPart2Start = false
        part2TopicCard = nil
        isTestComplete = false
        generatedReport = nil
        isTestStarted = false
        currentQuestion = ""
        
        // Clear any speech-related state
        speechErrorMessage = ""
        showSpeechError = false
        speechSubmittedSuccessfully = false
        
        // Reset audio
        audioLevel = 0.0
        isRecording = false
        textInput = ""
        originalTypedText = ""
    }
    
    private func startPart1() {
        print("🎯 Test started by user!")
        isTestStarted = true
        currentPart = 1
        
        if let test = currentTest {
            
            totalSteps = test.part1.count + 1 + test.part3.count
        }
        currentStep = 0
        
        timeRemaining = part1Duration
        isTimerActive = true
        if currentConversationID == nil, let context = modelContext {
            // 1. Create new conversation object
            let newConversation = Conversation(startDate: Date(), topic: currentTest?.topic ?? "General Practice", userEmail: currentUserEmail)
            
            // 2. Add it to database context
            context.insert(newConversation)
            
            // 3. Remember its ID and set persistence flag
            currentConversationID = newConversation.id
            isConversationPersisted = true
            
            // 4. Save to database immediately
            saveChanges()
        }
        
        let task = Task {
            // First, update the welcome message to remove the Start button
            if let welcomeMessageIndex = messages.firstIndex(where: {
                $0.role == .system && $0.content.contains("Welcome to your IELTS Speaking Test")
            }) {
                let originalMessage = messages[welcomeMessageIndex]
                // Create new message without action
                let updatedMessage = ChatMessage(
                    id: originalMessage.id,
                    role: originalMessage.role,
                    content: originalMessage.content,
                    isTyping: false,
                    timestamp: originalMessage.timestamp,
                    action: nil
                )
                messages[welcomeMessageIndex] = updatedMessage
                print("🔄 Removed Start button from welcome message")
            }
            
            // Add user "Start" message
            let startMessage = ChatMessage(
                role: .user,
                content: "Start",
                isTyping: false
            )
            messages.append(startMessage)
            
            // Save the start message if conversation is persisted
            if let conversation = getCurrentConversation(), isConversationPersisted {
                let dbMessage = Message(content: "Start", role: "user", timestamp: Date())
                conversation.messages.append(dbMessage)
                saveChanges()
            }
            
            // Wait for the introduction message to complete before asking the first question
            await streamMessage("Let's begin Part 1. I'll ask you some questions about familiar topics.", role: .system)
            
            // Only proceed to ask the first question after the intro is complete
            await askNextQuestion()
        }
        activeTasks.append(task)
    }
    
    private func askNextQuestion() async {
        guard let test = currentTest else {
            print("❌ No current test available")
            return
        }
        
        // Check if we have been cancelled
        guard !Task.isCancelled else {
            print("🚫 Task cancelled, stopping askNextQuestion")
            return
        }
        
        // Ensure currentQuestionIndex is within bounds
        guard currentQuestionIndex >= 0 && currentQuestionIndex < test.part1.count else {
            print("❌ Question index \(currentQuestionIndex) out of bounds (0..<\(test.part1.count))")
            transitionToPart2()
            return
        }
        
        let nextQuestion = test.part1[currentQuestionIndex]
        currentQuestion = nextQuestion
        
        // Check if cancelled before streaming message
        guard !Task.isCancelled else {
            print("🚫 Task cancelled before streaming question")
            return
        }
        
        await streamMessage(nextQuestion, role: .assistant)
    }
    
    private func transitionToPart2() {
        stopTimer()
        currentPart = 2
        currentQuestionIndex = 0
        isAwaitingPart2Start = true
        
        showPartTransition = true
        partTransitionText = "Part 1 Complete!\nTransitioning to Part 2..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showPartTransition = false
            guard let test = self.currentTest else { return }
            
            let part2Intro = """
            Part 1 is complete. We will now begin Part 2.

            In Part 2, I'll give you a topic card. You'll have 1 minute to prepare your answer, then you should speak for 1-2 minutes.

            Here is your topic:
            """

            let part2Topic = """
            **\(test.part2.topic)**

            You should say:
            • \(test.part2.cues.joined(separator: "\n• "))
            """
            
            Task {
                await self.streamMessage(part2Intro, role: .system)
                await self.streamMessage(part2Topic, role: .assistant)
                self.startTimer(duration: self.part2PrepTime)
                await self.streamMessage("Preparation time starts now. Use this time to think about what you want to say.", role: .system)
            }
        }
    }
        
    private func transitionToPart3() {
        stopTimer()
        currentPart = 3
        
        if currentStep < totalSteps {
            currentStep += 1
        }
        
        currentQuestionIndex = 0
        isAwaitingPart2Start = false
        
        showPartTransition = true
        partTransitionText = "Part 2 Complete!\nTransitioning to Part 3..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showPartTransition = false
            guard let test = self.currentTest else { return }
            
            let part3Intro = """
            Part 2 is complete. We will now begin Part 3.

            In Part 3, I'll ask you some more detailed questions related to the topic. This part focuses on your ability to discuss abstract ideas.
            """
            
            Task {
                await self.streamMessage(part3Intro, role: .system)
                if let firstQuestion = test.part3.first {
                    self.currentQuestion = firstQuestion
                    await self.streamMessage(firstQuestion, role: .assistant)
                    self.startTimer(duration: self.part3Duration)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
    }
    
    private func startTimer(duration: Int) {
        timeRemaining = duration
        isTimerActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeRemaining -= 1
            
            if self.timeRemaining <= 0 {
                self.stopTimer()
                
                switch self.currentPart {
                case 1:
                    self.transitionToPart2()
                case 2:
                    if self.isAwaitingPart2Start {
                        Task {
                            await self.streamMessage("Your preparation time is over. Now please speak for 1-2 minutes about your topic.", role: .system)
                        }
                        self.startTimer(duration: self.part2SpeakTime)
                        self.isAwaitingPart2Start = false
                    } else {
                        self.transitionToPart3()
                    }
                case 3:
                    self.completeTest()
                default:
                    break
                }
            }
        }
    }

    private func completeTest() {
        stopTimer()
        isTestComplete = true
        
        Task {
            // Сохраняем сообщение-заглушку в переменную
            let placeholderMessage = await streamMessage("You have completed the test! Generating your personalized feedback...", role: .system, withAnimation: true)

            if let conversation = getCurrentConversation() {
                conversation.isComplete = true
                saveChanges()
            }

            // Передаем сообщение-заглушку в следующую функцию
            await generatePersonalizedFeedback(placeholder: placeholderMessage)
        }
    }
    
    // In SpeakingPracticeViewModel.swift

    // In SpeakingPracticeViewModel.swift

    private func generatePersonalizedFeedback(placeholder: ChatMessage?) async {
        isLoading = true
        
        // Enhanced conversation data with more context for better scoring
        let conversationDTO = conversationHistoryForFeedback.enumerated().map { (index, qa) in
            // Calculate estimated response time based on text length and part
            let estimatedResponseTime = calculateEstimatedResponseTime(for: qa.answer, part: qa.part)
            
            // Calculate answer length metrics
            let wordCount = qa.answer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            let sentenceCount = qa.answer.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            
            // Determine question complexity based on part and content
            let questionComplexity = determineQuestionComplexity(question: qa.question, part: qa.part)
            
            return QuestionAnswerPairDTO(
                question: qa.question,
                answer: qa.answer,
                part: qa.part,
                topic: currentTest?.topic,
                answerLength: wordCount,
                responseTime: estimatedResponseTime,
                sentenceCount: sentenceCount,
                questionComplexity: questionComplexity,
                answerIndex: index + 1,
                totalQuestions: conversationHistoryForFeedback.count
            )
        }
        
        guard let token = KeychainManager.shared.getToken() else {
            await showGenericFeedback(placeholder: placeholder)
            return
        }
        
        // Create properly structured payload using Codable types
        let inputDistribution = calculateInputMethodDistribution()
        let metadata = TestMetadata(
            test_id: currentTest?.id ?? "unknown",
            test_topic: currentTest?.topic ?? "General Practice",
            total_parts_completed: Set(conversationHistoryForFeedback.map { $0.part }).count,
            session_duration_estimate: calculateSessionDuration(),
            user_input_method_distribution: InputMethodDistribution(
                voice: inputDistribution["voice"] ?? 0.7,
                text: inputDistribution["text"] ?? 0.3
            )
        )
        
        let enhancedPayload = EnhancedFeedbackPayload(
            conversation: conversationDTO,
            test_metadata: metadata
        )
        
        let result = await NetworkManager.shared.getFinalFeedbackEnhanced(payload: enhancedPayload, token: token)
        
        isLoading = false
        
        switch result {
        case .success(let feedback):
            // Enhanced feedback display with more detailed scoring explanation
            var feedbackText = """
            🎉 **Here is your comprehensive IELTS Speaking analysis!**

            ### Overall Band Score: \(String(format: "%.1f", feedback.overallBandScore))
            
            **Individual Scores:**
            • **Fluency & Coherence:** \(feedback.fluencyScore)/9
            • **Lexical Resource:** \(feedback.lexicalScore)/9  
            • **Grammatical Range & Accuracy:** \(feedback.grammarScore)/9
            • **Pronunciation:** \(feedback.pronunciationScore)/9
            
            ---
            
            ### Performance Summary
            \(feedback.generalSummary)
            
            ### Scoring Breakdown
            **Fluency & Coherence (\(feedback.fluencyScore)/9):**
            • Speech rate and flow
            • Use of cohesive devices
            • Logical sequencing of ideas
            
            **Lexical Resource (\(feedback.lexicalScore)/9):**
            • Range of vocabulary
            • Accuracy of word choice
            • Appropriate usage in context
            
            **Grammatical Range & Accuracy (\(feedback.grammarScore)/9):**
            • Variety of sentence structures
            • Grammatical accuracy
            • Complexity of language use
            
            **Pronunciation (\(feedback.pronunciationScore)/9):**
            • Individual sounds clarity
            • Word and sentence stress
            • Rhythm and intonation
            
            ---
            
            ### Detailed Answer Analysis
            """
            
            for (index, analysis) in feedback.answerAnalyses.enumerated() {
                let part = conversationHistoryForFeedback[safe: index]?.part ?? 1
                feedbackText += "\n\n### Part \(part) - Answer #\(index + 1)\n"
                feedbackText += "**Question:** \(analysis.question)\n"
                feedbackText += "**Your Answer:** *\"\(analysis.answer.prefix(100))\(analysis.answer.count > 100 ? "..." : "")\"*\n\n"
                
                feedbackText += "**Detailed Analysis:**\n"
                feedbackText += "• **Fluency:** \(analysis.fluencyFeedback)\n"
                
                if !analysis.grammarFeedback.isEmpty {
                    feedbackText += "• **Grammar Improvements:**\n"
                    for suggestion in analysis.grammarFeedback.prefix(3) { // Limit to top 3 suggestions
                        feedbackText += "  - *\"\(suggestion.sentence)\"* → \(suggestion.feedback)\n"
                        feedbackText += "    **Better:** *\"\(suggestion.suggestion)\"*\n"
                    }
                }
                
                if !analysis.vocabularyFeedback.isEmpty {
                    feedbackText += "• **Vocabulary Enhancements:**\n"
                    for suggestion in analysis.vocabularyFeedback.prefix(3) { // Limit to top 3 suggestions
                        feedbackText += "  - *\"\(suggestion.sentence)\"* → \(suggestion.feedback)\n"
                        feedbackText += "    **Alternative:** *\"\(suggestion.suggestion)\"*\n"
                    }
                }
                
                if analysis.grammarFeedback.isEmpty && analysis.vocabularyFeedback.isEmpty {
                    feedbackText += "• **Grammar & Vocabulary:** Well done! No major issues identified.\n"
                }
            }
            
            // Add improvement recommendations
            feedbackText += "\n\n### Key Recommendations for Improvement\n"
            feedbackText += generateImprovementRecommendations(feedback: feedback)
            
            updatePlaceholder(placeholder, with: feedbackText)
            
        case .failure(let error):
            print("❌ Failed to get AI feedback: \(error)")
            await showGenericFeedback(placeholder: placeholder)
        }
        
        generateDownloadFile()
    }
    
    /// Calculates estimated response time based on answer length and part complexity
    private func calculateEstimatedResponseTime(for answer: String, part: Int) -> TimeInterval {
        let wordCount = answer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let baseWordsPerSecond: Double = part == 1 ? 2.5 : (part == 2 ? 2.0 : 2.2) // Different pacing for different parts
        return Double(wordCount) / baseWordsPerSecond
    }
    
    /// Determines question complexity for better scoring context
    private func determineQuestionComplexity(question: String, part: Int) -> String {
        let questionLower = question.lowercased()
        
        switch part {
        case 1:
            return "basic" // Part 1 questions are generally straightforward
        case 2:
            return "intermediate" // Part 2 is monologue with preparation time
        case 3:
            // Part 3 complexity varies based on question type
            if questionLower.contains("why") || questionLower.contains("how") || questionLower.contains("what do you think") {
                return "complex"
            } else if questionLower.contains("compare") || questionLower.contains("advantage") || questionLower.contains("disadvantage") {
                return "advanced"
            } else {
                return "intermediate"
            }
        default:
            return "basic"
        }
    }
    
    /// Calculates total estimated session duration
    private func calculateSessionDuration() -> TimeInterval {
        return conversationHistoryForFeedback.reduce(0) { total, qa in
            total + calculateEstimatedResponseTime(for: qa.answer, part: qa.part)
        }
    }
    
    /// Calculates distribution of input methods used
    private func calculateInputMethodDistribution() -> [String: Double] {
        // This would need to be tracked during the session, for now return estimated values
        return [
            "voice": 0.7, // Assume 70% voice input
            "text": 0.3   // Assume 30% text input
        ]
    }
    
    /// Generates personalized improvement recommendations based on scores
    private func generateImprovementRecommendations(feedback: FeedbackResponse) -> String {
        var recommendations = ""
        
        // Fluency recommendations
        if feedback.fluencyScore < 6 {
            recommendations += "**Fluency & Coherence:**\n"
            recommendations += "• Practice speaking without long pauses\n"
            recommendations += "• Use linking words (however, therefore, furthermore)\n"
            recommendations += "• Organize your thoughts before speaking\n\n"
        }
        
        // Vocabulary recommendations
        if feedback.lexicalScore < 6 {
            recommendations += "**Vocabulary:**\n"
            recommendations += "• Learn topic-specific vocabulary\n"
            recommendations += "• Use synonyms to avoid repetition\n"
            recommendations += "• Practice collocations and phrasal verbs\n\n"
        }
        
        // Grammar recommendations
        if feedback.grammarScore < 6 {
            recommendations += "**Grammar:**\n"
            recommendations += "• Practice complex sentence structures\n"
            recommendations += "• Focus on verb tenses accuracy\n"
            recommendations += "• Use conditional sentences appropriately\n\n"
        }
        
        // Pronunciation recommendations
        if feedback.pronunciationScore < 6 {
            recommendations += "**Pronunciation:**\n"
            recommendations += "• Work on word stress patterns\n"
            recommendations += "• Practice intonation for questions and statements\n"
            recommendations += "• Focus on clear articulation of consonants\n\n"
        }
        
        // Overall band score recommendations
        if feedback.overallBandScore < 6.0 {
            recommendations += "**Overall Strategy:**\n"
            recommendations += "• Aim for longer, more detailed responses\n"
            recommendations += "• Practice with a variety of topics\n"
            recommendations += "• Record yourself and listen for improvements\n"
        } else if feedback.overallBandScore >= 7.0 {
            recommendations += "**Advanced Tips:**\n"
            recommendations += "• Use more sophisticated vocabulary\n"
            recommendations += "• Demonstrate cultural awareness in responses\n"
            recommendations += "• Show personal opinions with justification\n"
        }
        
        return recommendations.isEmpty ? "Keep practicing regularly to maintain your current level!" : recommendations
    }
    
    private func showGenericFeedback(placeholder: ChatMessage?) async {
        let genericFeedback = """
        🎉 **Congratulations! You have completed your IELTS Speaking practice session.**
        
        **Your Practice Summary:**
        • Part 1: ✅ Completed - Introduction and familiar topics
        • Part 2: ✅ Completed - Individual long turn
        • Part 3: ✅ Completed - Two-way discussion
        
        **General Tips for Improvement:**
        
        📌 **Fluency & Coherence:**
        • Speak naturally without long pauses
        • Use linking words to connect your ideas
        • Organize your thoughts clearly
        
        📌 **Vocabulary:**
        • Use a wide range of vocabulary
        • Include topic-specific terms
        • Avoid repetition where possible
        
        📌 **Grammar:**
        • Use various sentence structures
        • Mix simple and complex sentences
        • Pay attention to verb tenses
        
        📌 **Pronunciation:**
        • Speak clearly and at a natural pace
        • Focus on word stress and intonation
        • Practice difficult sounds regularly
        
        Keep practicing regularly to improve your speaking skills!
        """
        
        // Внутри showGenericFeedback()
        updatePlaceholder(placeholder, with: genericFeedback)
        
        // Generate the download file after feedback is shown
        generateDownloadFile()
    }
    
    private func updatePlaceholder(_ placeholder: ChatMessage?, with newContent: String) {
        guard let placeholder = placeholder, let index = messages.firstIndex(where: { $0.id == placeholder.id }) else {
            // Если по какой-то причине заглушка не найдена, просто отправляем новое сообщение
            Task { await streamMessage(newContent, role: .system, withAnimation: false) }
            return
        }

        // Обновляем контент существующего сообщения
        messages[index].content = newContent
        messages[index].isTyping = false

        // Обновляем сообщение и в базе данных
        if let conversation = getCurrentConversation() {
            if let dbMessage = conversation.messages.first(where: { $0.content.contains("Generating your personalized feedback") }) {
                dbMessage.content = newContent
                saveChanges()
            }
        }
    }
    
    private func generateDownloadFile() {
        guard let conversation = getCurrentConversation() else { return }
        
        // Create a text representation of the conversation
        var conversationText = "IELTS Speaking Practice Session\n"
        conversationText += "Date: \(Date().formatted())\n"
        conversationText += "Topic: \(currentTest?.topic ?? "General Practice")\n"
        conversationText += "\n" + String(repeating: "=", count: 50) + "\n\n"
        
        // Add all messages
        for message in messages {
            let role = message.role == .user ? "You" : "Examiner"
            conversationText += "\(role):\n\(message.content)\n\n"
        }
        
        // Create a temporary file
        let fileName = "IELTS_Practice_\(Date().formatted(.iso8601.year().month().day())).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try conversationText.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Store the URL for the share sheet
            self.generatedReportURL = tempURL
            
            print("✅ Conversation ready for download at: \(tempURL)")
        } catch {
            print("❌ Failed to create download file: \(error)")
        }
    }
    
    func downloadConversation() {
        // Когда пользователь нажимает кнопку, мы присваиваем URL
        // свойству, которое вызывает окно "Поделиться".
        if let url = generatedReportURL {
            self.reportURL = url
        } else {
            // Запасной вариант, если файл по какой-то причине не создался
            print("❌ Error: Report file is not available for download.")
        }
    }
    
    func startRecording() {
        do {
            // ✅ ИСПРАВЛЕНИЕ: Вызываем правильный метод start()
            try speechRecognitionService.start()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            // Вы можете добавить обработку ошибок здесь, например, показать alert
        }
    }

    func stopRecording() {
        // ✅ ИСПРАВЛЕНИЕ: Вызываем правильный метод stop()
        speechRecognitionService.stop()
    }
    
    // MARK: - Private Recording Methods
    
    private func handleUserResponse(_ response: String) {
        guard let test = currentTest else {
            print("❌ No current test available for handling user response")
            return
        }
        
        // Check if we have been cancelled
        guard !Task.isCancelled else {
            print("🚫 Task cancelled, stopping user response handling")
            return
        }
        
        // Add to conversation history for feedback
        conversationHistoryForFeedback.append(
            QAPair(part: currentPart, question: currentQuestion, answer: response)
        )
        
        // Proceed based on current part
        switch currentPart {
        case 1:
            proceedToNextQuestion()
        case 2:
            transitionToPart3()
        case 3:
            
            if currentStep < totalSteps {
                currentStep += 1
            }
            
            currentQuestionIndex += 1
            // Ensure bounds checking for Part 3
            if currentQuestionIndex >= 0 && currentQuestionIndex < test.part3.count {
                let nextQuestion = test.part3[currentQuestionIndex]
                currentQuestion = nextQuestion
                Task {
                    // Check if cancelled before streaming message
                    guard !Task.isCancelled else { return }
                    await streamMessage(nextQuestion, role: .assistant)
                }
            } else {
                print("📝 Part 3 completed, finishing test")
                completeTest()
            }
        default:
            completeTest()
        }
    }
    
    private func proceedToNextQuestion() {
        guard let test = currentTest else {
            print("❌ No current test available for proceeding to next question")
            return
        }
        
        // Check if we have been cancelled
        guard !Task.isCancelled else {
            print("🚫 Task cancelled, stopping proceedToNextQuestion")
            return
        }
        
        currentStep += 1
        
        currentQuestionIndex += 1
        
        // Ensure we don't exceed bounds
        if currentQuestionIndex >= 0 && currentQuestionIndex < test.part1.count {
            let nextQuestion = test.part1[currentQuestionIndex]
            currentQuestion = nextQuestion
            Task {
                guard !Task.isCancelled else { return }
                await streamMessage(nextQuestion, role: .assistant)
            }
        } else {
            print("📝 Part 1 completed, transitioning to Part 2")
            transitionToPart2()
        }
    }
    
    private func addPunctuation(to text: String) -> String {
        var processedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processedText.isEmpty else { return processedText }
    
        // Capitalize first letter
        if !processedText.isEmpty {
            processedText = processedText.prefix(1).uppercased() + processedText.dropFirst()
        }
    
        // Add ending punctuation if missing
        if !processedText.hasSuffix(".") && !processedText.hasSuffix("!") && !processedText.hasSuffix("?") {
            // Simple heuristic for question vs statement
            let lowercased = processedText.lowercased()
            if lowercased.hasPrefix("what ") || lowercased.hasPrefix("where ") ||
               lowercased.hasPrefix("when ") || lowercased.hasPrefix("why ") ||
               lowercased.hasPrefix("how ") || lowercased.hasPrefix("who ") {
                processedText += "?"
            } else {
                processedText += "."
            }
        }
        
        return processedText
    }
    
    // MARK: - Memory Management
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("✅ SpeakingPracticeViewModel: deinit успешно вызван и завершен.")
    }
    
    private func getCurrentConversation() -> Conversation? {
        guard let context = modelContext, let id = currentConversationID else { return nil }
        
        // Safe fetch with error handling
        for attempt in 1...3 {
            do {
                let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate<Conversation> { $0.id == id })
                return try context.fetch(descriptor).first
            } catch {
                print("❌ Попытка \(attempt) получения текущего диалога неудачна: \(error)")
                if attempt == 3 {
                    return nil
                }
                Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
            }
        }
        return nil
    }
    
    func renameConversation(id: UUID, newTitle: String) {
        guard let context = modelContext else { return }
        
        Task {
            await MainActor.run {
                // Safe fetch with error handling
                for attempt in 1...3 {
                    do {
                        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate<Conversation> { $0.id == id })
                        if let conversationToRename = try context.fetch(descriptor).first {
                            conversationToRename.topic = newTitle
                            saveChanges()
                            return
                        }
                        break
                    } catch {
                        print("❌ Попытка \(attempt) переименования диалога неудачна: \(error)")
                        if attempt == 3 {
                            print("⚠️ Не удалось переименовать диалог после 3 попыток")
                        } else {
                            Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                        }
                    }
                }
            }
        }
    }

    
    private func safeFetch<T>(_ block: () throws -> T) -> T? {
        guard !isCleaningUp, !Task.isCancelled else { return nil }
        do { return try block() } catch { print("❌ SwiftData error: \(error)"); return nil }
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
