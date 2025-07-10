import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserEmail") private var currentUserEmail: String = ""
    @Query private var conversations: [Conversation]
    @AppStorage("selectedVoice") private var selectedVoice: VoiceChoice = .femaleUS
    
    @State private var displayName: String = "" // Legacy field - now uses userDetails.name
    @State private var animateStats = false
    // В ProfileView.swift, после @State private var displayName: String = ""

    @State private var showingEditProfile = false
    @State private var showingAbout = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var showingChangePassword = false
    @State private var isExporting = false
    @State private var exportDocument: ExportDocument?
    @State private var showingExportDocument = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var policyURL: URL?
    @State private var profileImage: Image? // Также восстановим это для фото, если понадобится
    
    // MARK: - Computed Properties
    
    private var statsData: (total: Int, completed: Int, weeklyCount: Int) {
        let total = conversations.count
        let completed = conversations.filter { $0.isComplete }.count
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyCount = conversations.filter { $0.startDate >= oneWeekAgo }.count
        
        return (total, completed, weeklyCount)
    }

    init() {
        // Initialize from UserDefaults with user-specific key
        let defaults = UserDefaults.standard
        let currentEmail = defaults.string(forKey: "currentUserEmail") ?? ""
        let userSpecificKey = "displayName_\(currentEmail)"
        _displayName = State(initialValue: defaults.string(forKey: userSpecificKey) ?? "")
        
        // Filter conversations by current user
        _conversations = Query(
            filter: #Predicate<Conversation> { $0.userEmail == currentEmail },
            sort: \Conversation.startDate, order: .reverse
        )
    }
    
    // Save changes to UserDefaults
//    private func saveSettings() {
//        let defaults = UserDefaults.standard
//
//        defaults.set(practiceReminders, forKey: "practiceReminders")
//        defaults.set(reminderTime, forKey: "reminderTime")
//        defaults.set(displayName, forKey: "displayName")
//
//        // Handle notification scheduling
//        if practiceReminders {
//            requestNotificationPermission()
//        } else {
//            cancelAllNotifications()
//        }
//    }
    
//    private func requestNotificationPermission() {
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
//            DispatchQueue.main.async {
//                self.notificationPermissionGranted = granted
//                if granted {
//                    self.scheduleReminderNotifications()
//                } else {
//                    print("❌ Notification permission denied")
//                    self.showingNotificationAlert = true
//                }
//            }
//        }
//    }
    
//    private func scheduleReminderNotifications() {
//        // Cancel existing notifications first
//        cancelAllNotifications()
//
//        guard practiceReminders else { return }
//
//        let content = UNMutableNotificationContent()
//        content.title = "IELTS Practice Time! 🎤"
//        content.body = "Ready to improve your speaking skills? Start your daily practice session now!"
//        content.sound = .default
//        content.badge = 1
//
//        // Create date components from reminder time
//        let calendar = Calendar.current
//        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
//
//        // Schedule for every day at the specified time
//        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
//
//        let request = UNNotificationRequest(
//            identifier: "daily-practice-reminder",
//            content: content,
//            trigger: trigger
//        )
//
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("❌ Failed to schedule notification: \(error)")
//            } else {
//                print("✅ Daily reminder scheduled for \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
//            }
//        }
//    }
    
//    private func cancelAllNotifications() {
//        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-practice-reminder"])
//        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["daily-practice-reminder"])
//
//        // Clear badge count
//        UNUserNotificationCenter.current().setBadgeCount(0)
//
//        print("🔕 Cancelled all reminder notifications")
//
//        // Provide user feedback
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            // You could add a toast notification here if desired
//        }
//    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Profile Header
                    profileHeader
                    
                    // Practice Statistics
                    practiceStatistics
                    
                    // Settings Sections
                    VStack(spacing: DesignSystem.Spacing.md) {
                        voiceSettings
                        accountSettings
                        aboutSection
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditProfile = true }) {
                        Text("Edit")
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(displayName: $displayName)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
        }
//        .sheet(isPresented: $showingPrivacyPolicy) {
//            PrivacyPolicyView()
//        }
        .sheet(item: $policyURL) { url in
            SafariView(url: url)
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .fileExporter(
            isPresented: $showingExportDocument,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "IELTS_Practice_Data_\(Date().formatted(.iso8601.year().month().day())).txt"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ Data exported successfully to: \(url)")
            case .failure(let error):
                print("❌ Export failed: \(error)")
            }
        }

        .onChange(of: displayName) { _ in saveDisplayName() }
        .onAppear {
            // Animate statistics
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                animateStats = true
            }
            // Load displayName from user-specific UserDefaults first, then fall back to user details
            guard !currentUserEmail.isEmpty else { return }
            
            // Clean up old global displayName if it exists
            let oldGlobalName = UserDefaults.standard.string(forKey: "displayName")
            if let oldName = oldGlobalName, !oldName.isEmpty {
                UserDefaults.standard.removeObject(forKey: "displayName")
                print("🧹 Cleaned up old global displayName: \(oldName)")
            }
            
            let userSpecificKey = "displayName_\(currentUserEmail)"
            let savedName = UserDefaults.standard.string(forKey: userSpecificKey) ?? ""
            
            if !savedName.isEmpty {
                displayName = savedName
            } else if let userDetails = authManager.userDetails {
                displayName = userDetails.name ?? ""
                // Save it to user-specific storage for future use
                saveDisplayName()
            } else if let oldName = oldGlobalName, !oldName.isEmpty {
                // Migrate old global name to user-specific storage
                displayName = oldName
                saveDisplayName()
                print("📱 Migrated displayName for user: \(currentUserEmail)")
            }
            
            // Profile image functionality removed
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    await deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
        }

    }
    
    // MARK: - Practice Statistics
    private var practiceStatistics: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: "Practice Statistics", icon: "chart.bar.fill")
            
            if conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("No practice sessions yet")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Start practicing to see your progress here!")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    StatCard(
                        title: "Total",
                        value: "\(statsData.total)",
                        icon: "list.bullet.clipboard",
                        color: .blue,
                        animate: animateStats
                    )
                    
                    StatCard(
                        title: "Completed",
                        value: "\(statsData.completed)",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        animate: animateStats
                    )
                    
                    StatCard(
                        title: "This Week",
                        value: "\(statsData.weeklyCount)",
                        icon: "calendar",
                        color: .orange,
                        animate: animateStats
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Profile Image section removed as requested
            
            // User Info
            if let userDetails = authManager.userDetails {
                Text(userDetails.name ?? "IELTS Learner")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(userDetails.email)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                // Member Since - format the actual join date if available
                if let joinDate = userDetails.createdAt {
                    Text("Member since \(formatDate(joinDate))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }
    
    // Helper function to format the date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func saveDisplayName() {
        guard !currentUserEmail.isEmpty else { return }
        let userSpecificKey = "displayName_\(currentUserEmail)"
        UserDefaults.standard.set(displayName, forKey: userSpecificKey)
    }
    
    
    // MARK: - Account Settings
    private var voiceSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: "Voice Preference", icon: "speaker.wave.2.fill")
            
            // Новый, улучшенный список для выбора голоса
            VStack(alignment: .leading, spacing: 0) {
                ForEach(VoiceChoice.allCases) { voice in
                    // Каждая опция - это кнопка
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedVoice = voice
                        }
                    }) {
                        HStack {
                            Text(voice.displayName)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            // Показываем галочку для выбранного голоса
                            if selectedVoice == voice {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .contentShape(Rectangle()) // Делаем всю строку кликабельной
                    }
                    .buttonStyle(.plain) // Убираем стандартный стиль кнопки
                    
                    // Добавляем разделитель между опциями, кроме последней
                    if voice.id != VoiceChoice.allCases.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    private var accountSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: "Account", icon: "person.circle.fill")
            
            VStack(spacing: 0) {
                // Change Password
                Button(action: { showingChangePassword = true }) {
                    SettingRow(
                        icon: "lock.fill",
                        title: "Change Password",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    )
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.leading, 44)
                
                // Export Data
                Button(action: exportData) {
                    SettingRow(
                        icon: "square.and.arrow.up.fill",
                        title: "Export My Data",
                        trailing: {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    )
                }
                
                Divider()
                    .padding(.leading, 44)
                
                // Sign Out
                Button(action: { authManager.logout() }) {
                    SettingRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        titleColor: DesignSystem.Colors.error,
                        trailing: { EmptyView() }
                    )
                }
                
                Divider()
                    .padding(.leading, 44)
                
                // Delete Account
                Button(action: {
                    showDeleteAccountAlert = true
                }) {
                    SettingRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: "Delete Account",
                        titleColor: DesignSystem.Colors.error,
                        trailing: {
                            if isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                EmptyView()
                            }
                        }
                    )
                }
                .disabled(isDeletingAccount)
            }
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeader(title: "About", icon: "info.circle.fill")
            
            VStack(spacing: 0) {
                // About App
                Button(action: { showingAbout = true }) {
                    SettingRow(
                        icon: "info.circle",
                        title: "About IELTS Practice AI",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    )
                }
                
                Divider()
                    .padding(.leading, 44)
                
                // Privacy Policy
                Button(action: {
                    policyURL = URL(string: "https://www.privacypolicies.com/live/d7662810-bda4-4d31-be92-d52b1413c841")
                }) {
                    SettingRow(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    )
                }
                
//                Divider()
//                    .padding(.leading, 44)
//
//                // Terms of Service
//                Button(action: { showingTermsOfService = true }) {
//                    SettingRow(
//                        icon: "doc.text.fill",
//                        title: "Terms of Service",
//                        trailing: {
//                            Image(systemName: "chevron.right")
//                                .font(.caption)
//                                .foregroundColor(DesignSystem.Colors.textTertiary)
//                        }
//                    )
//                }
            }
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
    }
    
    // MARK: - Helper Functions
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let exportData = await gatherUserData()
                let formattedText = formatDataAsText(exportData)
                let textData = formattedText.data(using: .utf8) ?? Data()
                
                await MainActor.run {
                    exportDocument = ExportDocument(data: textData)
                    showingExportDocument = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to prepare export data: \(error)")
                    isExporting = false
                }
            }
        }
    }
    
    private func formatDataAsText(_ data: UserExportData) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateStyle = .medium
        shortDateFormatter.timeStyle = .short
        
        var text = """
        =====================================
        IELTS PRACTICE AI - DATA EXPORT
        =====================================
        
        Export Date: \(dateFormatter.string(from: data.exportDate))
        
        =====================================
        USER PROFILE
        =====================================
        
        Email: \(data.userProfile.email)
        Name: \(data.userProfile.name ?? "Not set")
        Member Since: \(data.userProfile.joinDate.map { dateFormatter.string(from: $0) } ?? "Unknown")
        """
        
        text += """
        
        
        =====================================
        PRACTICE SUMMARY
        =====================================
        
        Total Conversations: \(data.totalConversations)
        Completed Sessions: \(data.completedSessions)
        Average Band Score: \(data.conversations.isEmpty ? "N/A" : String(format: "%.1f", data.conversations.map { $0.overallBandScore }.reduce(0, +) / Double(data.conversations.count)))
        
        
        =====================================
        CONVERSATION HISTORY
        =====================================
        
        """
        
        for (index, conversation) in data.conversations.enumerated() {
            text += """
            
            CONVERSATION \(index + 1)
            ------------------------------------
            Topic: \(conversation.topic)
            Date: \(shortDateFormatter.string(from: conversation.startDate))
            Status: \(conversation.isComplete ? "Completed" : "In Progress")
            Band Score: \(String(format: "%.1f", conversation.overallBandScore))
            Messages: \(conversation.messages.count)
            
            CONVERSATION CONTENT:
            """
            
            for (msgIndex, message) in conversation.messages.enumerated() {
                let speaker = message.role == "user" ? "YOU" : "AI COACH"
                let timestamp = shortDateFormatter.string(from: message.timestamp)
                
                text += """
                
                [\(msgIndex + 1)] \(speaker) (\(timestamp)):
                \(message.content)
                """
            }
            
            text += "\n\n" + String(repeating: "-", count: 50)
        }
        
        text += """
        
        
        =====================================
        END OF EXPORT
        =====================================
        
        This file contains your complete IELTS Practice AI data.
        You can open this file with any text editor on your phone, tablet, or computer.
        
        """
        
        return text
    }
    
    private func gatherUserData() async -> UserExportData {
        let userEmail = currentUserEmail
        
        // Fetch conversations for current user
        let predicate = #Predicate<Conversation> { $0.userEmail == userEmail }
        let fetchDescriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Conversation.startDate, order: .reverse)])
        
        var conversations: [ExportConversation] = []
        
        // Safe fetch with error handling
        for attempt in 1...3 {
            do {
                let userConversations = try modelContext.fetch(fetchDescriptor)
                conversations = userConversations.map { conversation in
                    let messages = conversation.messages.map { message in
                        ExportMessage(
                            content: message.content,
                            role: message.role,
                            timestamp: message.timestamp
                        )
                    }
                    
                    return ExportConversation(
                        id: conversation.id.uuidString,
                        topic: conversation.topic,
                        startDate: conversation.startDate,
                        isComplete: conversation.isComplete,
                        overallBandScore: conversation.overallBandScore,
                        messages: messages
                    )
                }
                break
            } catch {
                print("❌ Попытка \(attempt) экспорта данных неудачна: \(error)")
                if attempt == 3 {
                    conversations = []
                } else {
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                }
            }
        }
        
        let userProfile = ExportUserProfile(
            email: authManager.userDetails?.email ?? userEmail,
            name: displayName.isEmpty ? nil : displayName,
            joinDate: authManager.userDetails?.createdAt
        )
        
        return UserExportData(
            exportDate: Date(),
            userProfile: userProfile,
            conversations: conversations,
            totalConversations: conversations.count,
            completedSessions: conversations.filter { $0.isComplete }.count
        )
    }
    
    private func deleteAccount() async {
        // Clear local data for current user
        clearDataForCurrentUser()
        // Delete account on server
        await authManager.deleteAccount()
    }
    
    private func clearDataForCurrentUser() {
        let emailToFilter = self.currentUserEmail
        let predicate = #Predicate<Conversation> { $0.userEmail == emailToFilter }
        
        let fetchDescriptor = FetchDescriptor(predicate: predicate)
        
        // Safe fetch with error handling
        for attempt in 1...3 {
            do {
                let userConversations = try modelContext.fetch(fetchDescriptor)
                for conversation in userConversations {
                    modelContext.delete(conversation)
                }
                try modelContext.save()
                print("✅ Cleared all local data for user \(self.currentUserEmail).")
                return
            } catch {
                print("❌ Попытка \(attempt) очистки данных неудачна: \(error)")
                if attempt == 3 {
                    print("❌ Failed to clear local data for user \(self.currentUserEmail): \(error)")
                } else {
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                }
            }
        }
    }
    
//    private func checkNotificationPermission() {
//        UNUserNotificationCenter.current().getNotificationSettings { settings in
//            DispatchQueue.main.async {
//                self.notificationPermissionGranted = settings.authorizationStatus == .authorized
//
//                // If reminders are enabled but permission is denied, we should reschedule
//                if self.practiceReminders && settings.authorizationStatus == .authorized {
//                    self.scheduleReminderNotifications()
//                }
//
//                // Check active notifications
//                self.checkActiveNotifications()
//            }
//        }
//    }
    
//    private func checkActiveNotifications() {
//        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
//            DispatchQueue.main.async {
//                self.activeNotificationsCount = requests.filter { $0.identifier == "daily-practice-reminder" }.count
//            }
//        }
//    }
    
    // MARK: - Photo Management Methods
    
    private static func loadProfileImage() -> Image? {
        guard let imageData = UserDefaults.standard.data(forKey: "profileImageData"),
              let uiImage = UIImage(data: imageData) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    private func saveProfileImage(_ uiImage: UIImage) {
        // Resize image for better storage efficiency
        let resizedImage = resizeImage(uiImage, to: DesignSystem.Photo.maxImageSize)
        
        // Compress and save image
        if let imageData = resizedImage.jpegData(compressionQuality: DesignSystem.Photo.compressionQuality) {
            UserDefaults.standard.set(imageData, forKey: "profileImageData")
            profileImage = Image(uiImage: resizedImage)
            print("✅ Profile image saved successfully")
        }
    }
    
    private func resizeImage(_ image: UIImage, to maxSize: CGFloat) -> UIImage {
        let size = image.size
        let maxDimension = max(size.width, size.height)
        
        // Only resize if image is larger than maxSize
        if maxDimension <= maxSize {
            return image
        }
        
        let scale = maxSize / maxDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func deleteProfileImage() {
        UserDefaults.standard.removeObject(forKey: "profileImageData")
        withAnimation(.spring()) {
            profileImage = nil
        }
        print("🗑️ Profile image deleted")
    }
    
    // Save changes to UserDefaults

    /*
    @MainActor
    private func loadConversations() async {
        guard debounceExpired() else {
            print("⏸️ Skipping fetch – context debounce window still active")
            return
        }
        ...
        let all = try modelContext.fetch(descriptor)   // ← SAFE now
    }

    private func debounceExpired() -> Bool {
        // 2-second safety window
        return Date().timeIntervalSince(lastContextChange) > 2
    }
    */
}

// MARK: - Supporting Views
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.accent)
            
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

struct SettingRow<Trailing: View>: View {
    let icon: String
    let title: String
    var titleColor: Color = DesignSystem.Colors.textPrimary
    @ViewBuilder let trailing: () -> Trailing
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 24)
            
            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundColor(titleColor)
            
            Spacer()
            
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var name = ""
    @Binding var displayName: String
    
    init(displayName: Binding<String>) {
        self._displayName = displayName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $name)
                        .autocorrectionDisabled()
                        .padding()
                        .background(DesignSystem.Colors.cardBackground)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                .stroke(DesignSystem.Colors.separator, lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadUserData()
        }
    }
    
    private func loadUserData() {
        // Load from user details first, then fallback to binding value
        if let userDetails = authManager.userDetails {
            name = userDetails.name ?? ""
        } else {
            name = displayName
        }
    }
    
    private func saveProfile() {
        // Update the binding to reflect in parent view immediately
        displayName = name
        
        // Save to server
        Task {
            await authManager.updateProfile(name: name)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // App Icon
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.top, DesignSystem.Spacing.xl)
                    
                    Text("IELTS Practice AI")
                        .font(DesignSystem.Typography.largeTitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Version 1.0.0")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    // Description
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("About")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("IELTS Practice AI is your personal AI-powered IELTS speaking coach. Practice anytime, anywhere, and get instant feedback to improve your band score.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Features
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Features")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        FeatureRow(icon: "mic.fill", title: "Real-time Speaking Practice", description: "Practice with AI-powered conversations")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your improvement over time")
                        FeatureRow(icon: "brain", title: "Smart Feedback", description: "Get personalized tips and corrections")
                        FeatureRow(icon: "clock.fill", title: "Flexible Practice", description: "Practice anytime at your own pace")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Credits
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Made with ❤️ for IELTS learners")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("© 2025 IELTS Practice AI")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.bodyBold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Change Password View
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isCurrentPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                            .foregroundColor(DesignSystem.Colors.accent)
                        
                        Text("Change Password")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Enter your current password and choose a new one")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Form
                    VStack(spacing: DesignSystem.Spacing.md) {
                        // Current Password
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Current Password")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            HStack(spacing: 8) {
                                if isCurrentPasswordVisible {
                                    TextField("Enter current password", text: $currentPassword)
                                } else {
                                    SecureField("Enter current password", text: $currentPassword)
                                }
                                
                                Button(action: { isCurrentPasswordVisible.toggle() }) {
                                    Image(systemName: isCurrentPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        
                        // New Password
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("New Password")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            HStack(spacing: 8) {
                                if isNewPasswordVisible {
                                    TextField("Enter new password", text: $newPassword)
                                } else {
                                    SecureField("Enter new password", text: $newPassword)
                                }
                                
                                Button(action: { isNewPasswordVisible.toggle() }) {
                                    Image(systemName: isNewPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Confirm New Password")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            HStack(spacing: 8) {
                                if isConfirmPasswordVisible {
                                    TextField("Confirm new password", text: $confirmPassword)
                                } else {
                                    SecureField("Confirm new password", text: $confirmPassword)
                                }
                                
                                Button(action: { isConfirmPasswordVisible.toggle() }) {
                                    Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        
                        // Password Requirements
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            PasswordRequirementsView(password: newPassword, confirmPassword: confirmPassword)
                        }
                        .padding(.top, DesignSystem.Spacing.sm)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                    
                    // Change Password Button
                    Button(action: changePassword) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isLoading ? "Changing Password..." : "Change Password")
                                .font(DesignSystem.Typography.button)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                    }
                    .disabled(!isFormValid || isLoading)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been changed successfully!")
            }
        }
    }
    
    private var passwordsMatch: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= PasswordValidator.minimumLength &&
        passwordsMatch
    }
    
    private func changePassword() {
        guard isFormValid else {
            errorMessage = "Please ensure passwords match and are at least \(PasswordValidator.minimumLength) characters long."
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            let result = await NetworkManager.shared.changePassword(
                current: currentPassword,
                new: newPassword
            )
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    showSuccess = true
                case .failure(let error):
                    if let networkError = error as? NetworkError, case .serverError(let detail) = networkError {
                        errorMessage = detail
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }
}

// MARK: - Export Data Structures
struct UserExportData: Codable {
    let exportDate: Date
    let userProfile: ExportUserProfile
    let conversations: [ExportConversation]
    let totalConversations: Int
    let completedSessions: Int
}

struct ExportUserProfile: Codable {
    let email: String
    let name: String?
    let joinDate: Date?
}

struct ExportConversation: Codable {
    let id: String
    let topic: String
    let startDate: Date
    let isComplete: Bool
    let overallBandScore: Double
    let messages: [ExportMessage]
}

struct ExportMessage: Codable {
    let content: String
    let role: String
    let timestamp: Date
}

// MARK: - Export Document
class ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(DesignSystem.Colors.accent)
                        
                        Text("Terms of Service")
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Last updated: January 27, 2025")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Content
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        
                        PolicySection(
                            title: "Acceptance of Terms",
                            content: """
                            By downloading, installing, or using IELTS Practice AI, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service.
                            """
                        )
                        
                        PolicySection(
                            title: "Description of Service",
                            content: """
                            IELTS Practice AI is an educational app designed to help users practice for the IELTS Speaking test through:
                            
                            • AI-powered conversation practice
                            • Speech analysis and feedback
                            • Progress tracking and scoring
                            • Personalized learning recommendations
                            
                            Our service is for educational purposes and does not guarantee specific test results.
                            """
                        )
                        
                        PolicySection(
                            title: "User Accounts and Responsibilities",
                            content: """
                            You are responsible for:
                            
                            • Providing accurate account information
                            • Maintaining the security of your account
                            • All activities that occur under your account
                            • Using the service in compliance with applicable laws
                            
                            You must not:
                            • Share your account credentials
                            • Use the service for illegal purposes
                            • Attempt to reverse engineer our technology
                            • Violate any intellectual property rights
                            """
                        )
                        
                        PolicySection(
                            title: "Subscription and Payments",
                            content: """
                            • Subscription fees are charged in advance
                            • Subscriptions automatically renew unless cancelled
                            • Refunds are subject to App Store/Google Play policies
                            • Prices may change with 30 days notice
                            • Free trial terms are clearly disclosed at signup
                            
                            You can manage your subscription through your device's app store settings.
                            """
                        )
                        
                        PolicySection(
                            title: "Intellectual Property",
                            content: """
                            IELTS Practice AI and all related content, features, and functionality are owned by us and are protected by international copyright, trademark, and other intellectual property laws.
                            
                            You retain ownership of content you create, but grant us a license to use it for service improvement and AI training purposes.
                            """
                        )
                        
                        PolicySection(
                            title: "Limitation of Liability",
                            content: """
                            IELTS Practice AI is provided "as is" without warranties of any kind. We do not guarantee:
                            
                            • Specific IELTS test score improvements
                            • Uninterrupted service availability
                            • Error-free operation
                            • Compatibility with all devices
                            
                            Our liability is limited to the amount you paid for the service in the past 12 months.
                            """
                        )
                        
                        PolicySection(
                            title: "Termination",
                            content: """
                            We may terminate or suspend your account if you:
                            
                            • Violate these terms
                            • Engage in fraudulent activity
                            • Abuse our service or support team
                            • Fail to pay subscription fees
                            
                            You may terminate your account at any time through the app settings.
                            """
                        )
                        
                        PolicySection(
                            title: "Changes to Terms",
                            content: """
                            We reserve the right to modify these terms at any time. Significant changes will be communicated through the app or email. Continued use after changes constitutes acceptance of new terms.
                            """
                        )
                        
                        PolicySection(
                            title: "Governing Law",
                            content: """
                            These terms are governed by the laws of [Your Jurisdiction]. Any disputes will be resolved through binding arbitration or in the courts of [Your Jurisdiction].
                            """
                        )
                        
                        PolicySection(
                            title: "Contact Information",
                            content: """
                            For questions about these Terms of Service:
                            
                            Email: legal@ielts-practice-ai.com
                            Website: https://ielts-practice-ai.com/terms
                            
                            IELTS Practice AI Team
                            """
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Policy Section Component
struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(content)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

// MARK: - Statistics Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animate: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .scaleEffect(animate ? 1.0 : 0.8)
                .opacity(animate ? 1.0 : 0.0)
            
            Text(title)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.3)), value: animate)
    }
}
