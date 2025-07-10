// In the TaskListViewModel.swift file
import Foundation

// --- CORRECTION 1: Recreate missing structures ---
// Since we removed ChatModels.swift, we need to declare these
// simple structures again, which are only used in this file.
struct TokenResponse: Decodable {
    let access_token: String
}

struct ChatResponse: Decodable {
    let response: String
}

// Legacy ChatMessage for backward compatibility (simplified version)
struct LegacyChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    
    enum Role: String, Codable, CaseIterable {
        case user
        case assistant
        case system
        case error
    }
    
    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}


@MainActor
class TaskListViewModel: ObservableObject {
    
    @Published var tasks: [TaskItem] = []
    @Published var chatMessages: [LegacyChatMessage] = [] // Uses legacy ChatMessage model
    @Published var authToken: String?
    @Published var isAuthenticated: Bool = false
    @Published var loginError: String?

    private let apiBaseURL = "http://139.59.158.227:8000"

    func login(username: String, password: String) async {
        guard let url = URL(string: "\(apiBaseURL)/token") else {
            loginError = "Invalid URL"; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "username=\(username)&password=\(password)".data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                loginError = "Invalid username or password."; return
            }
            // This line will now work since TokenResponse is declared above
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            self.authToken = tokenResponse.access_token
            self.isAuthenticated = true
            self.loginError = nil
        } catch {
            loginError = "Login failed."
        }
    }

    func sendMessage(_ prompt: String) async {
        guard let token = authToken else { return }
        guard let url = URL(string: "\(apiBaseURL)/chatbot") else { return }
        
        // --- CORRECTION 2: Use new initializer for LegacyChatMessage ---
        chatMessages.append(LegacyChatMessage(role: .user, content: prompt))
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = ["prompt": prompt]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // This line will now work
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            // --- CORRECTION 3: Use new initializer ---
            chatMessages.append(LegacyChatMessage(role: .assistant, content: chatResponse.response))
            
        } catch {
            // --- CORRECTION 4: Use new initializer ---
            chatMessages.append(LegacyChatMessage(role: .error, content: "Error communicating with AI."))
        }
    }
    
    func downloadReport() async -> URL? {
        // --- CORRECTION 5: Adapt data for old API ---
        // Your old backend expects 'text' and 'isFromUser' fields.
        // Let's create a temporary structure that matches it.
        struct LegacyReportMessage: Encodable {
            let text: String
            let isFromUser: Bool
        }
        
        // Convert our legacy ChatMessage to old format
        let reportHistory = chatMessages.map { message in
            LegacyReportMessage(text: message.content, isFromUser: message.role == .user)
        }
        
        // The payload now uses this temporary structure
        struct ReportPayload: Encodable {
            let history: [LegacyReportMessage]
        }
        
        guard let token = authToken else { return nil }
        guard let url = URL(string: "\(apiBaseURL)/chatbot/report") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Encode the payload in the correct format
        let payload = ReportPayload(history: reportHistory)
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ielts_report.txt")
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Error downloading report: \(error)")
            return nil
        }
    }
    
    // Other functions (fetchTasks, createTask) remain unchanged
    func fetchTasks() async {
        guard isAuthenticated, let token = authToken else { return }
        guard let url = URL(string: "\(apiBaseURL)/tasks/") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
        } catch {
            tasks = []
        }
    }
    
    func createTask(title: String, description: String) async {
        guard isAuthenticated, let token = authToken else { return }
        guard let url = URL(string: "\(apiBaseURL)/tasks/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = ["title": title, "description": description]
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            _ = try await URLSession.shared.data(for: request)
            await fetchTasks()
        } catch {
            print("Error creating task: \(error)")
        }
    }
}
