// HistoryView.swift (Complete version with @Query)

import SwiftUI
import SwiftData

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case incomplete = "Incomplete"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .completed: return "checkmark.circle"
        case .incomplete: return "clock.circle"
        }
    }
}

struct HistoryView: View {
    // This @Query will be a "live" connection to your database.
    // It will automatically update the list when conversations are added or removed.
    @Query private var conversations: [Conversation]
    
    // Actions that we pass from MainAppView
    var onNewChat: () -> Void
    var onSelectConversation: (Conversation) -> Void
    var onRenameConversation: (UUID, String) -> Void
    var onDeleteMultiple: (Set<UUID>) -> Void
    var isTtsEnabled: Bool
    var onToggleTts: (Bool) -> Void

    // Local state for this View
    @State private var isEditMode = false
    @State private var selections = Set<UUID>()
    @State private var conversationToDeleteInfo: (id: UUID, topic: String)?
    @State private var isShowingMultiDeleteAlert = false
    @State private var isShowingRenameAlert = false
    @State private var conversationToRenameInfo: (id: UUID, topic: String)?
    @State private var newTitle: String = ""
    @State private var deletingIDs = Set<UUID>()
    @State private var editingConversationId: UUID?
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingFilterOptions = false


    // Special init for filtering conversations by current user
    // In the HistoryView.swift file

    init(
        isTtsEnabled: Bool,
        onToggleTts: @escaping (Bool) -> Void,
        onNewChat: @escaping () -> Void,
        onSelectConversation: @escaping (Conversation) -> Void,
        onRenameConversation: @escaping (UUID, String) -> Void,
        onDeleteMultiple: @escaping (Set<UUID>) -> Void
    ) {
        // 1. Filtering for @Query by current user
        let email = UserDefaults.standard.string(forKey: "currentUserEmail") ?? ""
        _conversations = Query(
            filter: #Predicate<Conversation> { $0.userEmail == email },
            sort: \Conversation.startDate, order: .reverse
        )

        // 2. Setting all properties, including new ones
        self.isTtsEnabled = isTtsEnabled
        self.onToggleTts = onToggleTts
        self.onNewChat = onNewChat
        self.onSelectConversation = onSelectConversation
        self.onRenameConversation = onRenameConversation
        self.onDeleteMultiple = onDeleteMultiple
    }
    
    // MARK: - Computed Properties
    
    private var filteredConversations: [Conversation] {
        let filtered = conversations.filter { conversation in
            // Category filter only
            switch selectedFilter {
            case .all:
                return true
            case .completed:
                return conversation.isComplete
            case .incomplete:
                return !conversation.isComplete
            }
        }
        return filtered
    }
    

    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compact Header with Search - extend to top edge
                VStack(spacing: 16) {
                    // Safe area padding for status bar
                    Color.clear
                        .frame(height: geometry.safeAreaInsets.top)
                    
                    // Title and Edit Button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Practice History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        if !conversations.isEmpty {
                            Text("\(conversations.count) practice sessions")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Filter Button
                        Button(action: { showingFilterOptions.toggle() }) {
                            Image(systemName: selectedFilter.icon)
                                .font(.title2)
                                .foregroundColor(DesignSystem.Colors.accent)
                                .frame(width: 44, height: 44)
                                .background(DesignSystem.Colors.surfaceBackground)
                                .clipShape(Circle())
                        }
                        
                        // Edit Button
                        if !conversations.isEmpty {
                            Button(isEditMode ? "Done" : "Select") {
                                withAnimation(.spring()) {
                                    isEditMode.toggle()
                                    if !isEditMode {
                                        selections.removeAll()
                                    }
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                }
                
                // New Chat Button
                Button(action: onNewChat) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Start New Practice Session")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(DesignSystem.Colors.background)

            // Conversation List - Fill remaining space
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredConversations.isEmpty {
                        VStack(spacing: 24) {
                            Image(systemName: "message.circle")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Text("No conversations yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("Tap 'Start New Practice Session' to begin your IELTS journey")
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            if !searchText.isEmpty || selectedFilter != .all {
                                Button("Clear Filters") {
                                    withAnimation {
                                        searchText = ""
                                        selectedFilter = .all
                                    }
                                }
                                .foregroundColor(DesignSystem.Colors.accent)
                                .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(filteredConversations) { conversation in
                            ConversationCard(
                                conversation: conversation,
                                isEditMode: isEditMode,
                                isSelected: selections.contains(conversation.id),
                                isDeleting: deletingIDs.contains(conversation.id),
                                onTap: {
                                    if isEditMode {
                                        toggleSelection(for: conversation.id)
                                    } else {
                                        onSelectConversation(conversation)
                                    }
                                },
                                onLongPress: {
                                    if !isEditMode {
                                        withAnimation(.spring()) {
                                            isEditMode = true
                                            selections = [conversation.id]
                                        }
                                    }
                                },
                                onSelect: {
                                    toggleSelection(for: conversation.id)
                                },
                                onRename: {
                                    conversationToRenameInfo = (id: conversation.id, topic: conversation.topic)
                                    newTitle = conversation.topic
                                    isShowingRenameAlert = true
                                },
                                onDelete: {
                                    conversationToDeleteInfo = (id: conversation.id, topic: conversation.topic)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .refreshable {
                // Add pull-to-refresh functionality if needed
            }
                // --- Alert Modifiers ---
            .alert("Delete Conversation?", isPresented: .constant(conversationToDeleteInfo != nil), actions: {
                Button("Delete", role: .destructive) {
                    if let info = conversationToDeleteInfo {
                        // Анимация
                        withAnimation(.spring()) {
                            deletingIDs.insert(info.id)
                        }
                        // Вызываем ту же функцию, что и для множественного удаления,
                        // но передаем ей массив из одного элемента.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onDeleteMultiple([info.id]) // <--- ИЗМЕНЕНИЕ
                            deletingIDs.remove(info.id)
                        }
                    }
                    conversationToDeleteInfo = nil
                }
                Button("Cancel", role: .cancel) {
                    conversationToDeleteInfo = nil
                }
            }, message: {
                Text("Are you sure you want to permanently delete \(conversationToDeleteInfo?.topic ?? "this conversation")?")
            })
            .alert("Rename Conversation", isPresented: $isShowingRenameAlert, actions: {
                TextField("New title", text: $newTitle)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if let info = conversationToRenameInfo {
                            onRenameConversation(info.id, newTitle)
                        }
                        newTitle = ""
                        editingConversationId = nil
                    }
                Button("Rename") {
                    if let info = conversationToRenameInfo {
                        onRenameConversation(info.id, newTitle)
                    }
                    isShowingRenameAlert = false
                    conversationToRenameInfo = nil
                }
                Button("Cancel", role: .cancel) {
                    isShowingRenameAlert = false
                    conversationToRenameInfo = nil
                }
            }, message: {
                Text("Enter a new name for this conversation")
            })
            .alert("Delete Multiple Conversations?", isPresented: $isShowingMultiDeleteAlert, actions: {
                Button("Delete \(selections.count)", role: .destructive) {
                    // Добавляем ту же логику анимации, что и для одиночного удаления
                    withAnimation {
                        deletingIDs.formUnion(selections)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onDeleteMultiple(selections)
                        selections.removeAll()
                        isEditMode = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            }, message: {
                Text("Are you sure you want to permanently delete these selected items?")
            })

            // Footer section - fixed at bottom with tab bar padding
            VStack(spacing: 16) {
                if isEditMode {
                    // Multi-delete button
                    Button(action: {
                        if !selections.isEmpty {
                            isShowingMultiDeleteAlert = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.headline)
                            Text("Delete Selected (\(selections.count))")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selections.isEmpty ? Color.gray : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(selections.isEmpty ? 0.95 : 1.0)
                    }
                    .disabled(selections.isEmpty)
                    .animation(.spring(), value: selections.count)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // TTS toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Text-to-Speech")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("Enable voice responses from assistant")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { self.isTtsEnabled },
                            set: { newIsOn in self.onToggleTts(newIsOn) }
                        ))
                        .labelsHidden()
                    }
                    .padding(16)
                    .background(DesignSystem.Colors.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
                // Tab bar safe area padding
                Color.clear
                    .frame(height: geometry.safeAreaInsets.bottom)
            }
            .background(DesignSystem.Colors.background)
            .edgesIgnoringSafeArea(.all)
            .animation(.spring(), value: isEditMode)
        }

        // Filter Sheet
        .sheet(isPresented: $showingFilterOptions) {
            FilterSheet(selectedFilter: $selectedFilter)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func toggleSelection(for id: UUID) {
        withAnimation(.bouncy(duration: 0.2)) {
            if selections.contains(id) {
                selections.remove(id)
            } else {
                selections.insert(id)
            }
        }
    }
}

// MARK: - Supporting Components

struct ConversationCard: View {
    let conversation: Conversation
    let isEditMode: Bool
    let isSelected: Bool
    let isDeleting: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator (edit mode)
            if isEditMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isSelected)
                }
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(conversation.topic)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if conversation.isComplete {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.success)
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.success)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.success.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(conversation.startDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(conversation.startDate, style: .time)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            // Action buttons (normal mode)
            if !isEditMode {
                HStack(spacing: 8) {
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.accent)
                            .frame(width: 36, height: 36)
                            .background(DesignSystem.Colors.accent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.error)
                            .frame(width: 36, height: 36)
                            .background(DesignSystem.Colors.error.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDeleting ? Color.red.opacity(0.1) : DesignSystem.Colors.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? DesignSystem.Colors.accent : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.6 : 1.0)
        .offset(x: isDeleting ? -20 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDeleting)
        .animation(.spring(response: 0.3), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
}

struct FilterSheet: View {
    @Binding var selectedFilter: HistoryFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Filter Conversations")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Single horizontal row with all 3 filters
                HStack(spacing: 12) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: filter.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedFilter == filter ? .white : DesignSystem.Colors.accent)
                                
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedFilter == filter ? .white : DesignSystem.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedFilter == filter ? DesignSystem.Colors.accent : DesignSystem.Colors.surfaceBackground)
                            )
                        }
                        .scaleEffect(selectedFilter == filter ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3), value: selectedFilter)
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
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
