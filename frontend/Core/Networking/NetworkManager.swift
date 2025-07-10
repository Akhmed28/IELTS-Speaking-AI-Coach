import Foundation

// MARK: - Network Models
struct ConversationDTO: Codable {
    let id: Int
    let created_at: String
    let conversation: [QuestionAnswerPairDTO]
}

struct QuestionAnswerPairDTO: Codable {
    let question: String
    let answer: String
    let part: Int?
    let topic: String?
    let answerLength: Int?
    let responseTime: TimeInterval?
    let sentenceCount: Int?
    let questionComplexity: String?
    let answerIndex: Int?
    let totalQuestions: Int?
    
    init(question: String,
         answer: String,
         part: Int? = nil,
         topic: String? = nil,
         answerLength: Int? = nil,
         responseTime: TimeInterval? = nil,
         sentenceCount: Int? = nil,
         questionComplexity: String? = nil,
         answerIndex: Int? = nil,
         totalQuestions: Int? = nil) {
        self.question = question
        self.answer = answer
        self.part = part
        self.topic = topic
        self.answerLength = answerLength
        self.responseTime = responseTime
        self.sentenceCount = sentenceCount
        self.questionComplexity = questionComplexity
        self.answerIndex = answerIndex
        self.totalQuestions = totalQuestions
    }
}

struct ConversationPayload: Codable {
    let conversation: [QuestionAnswerPairDTO]
}



enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(String)
    case encodingError(String)
    case noData
    case networkError(String)
    case connectionError(String)
}


class NetworkManager {
    static let shared = NetworkManager()
    // Use this for the Simulator
//    private let baseURL = "http://:8000"
    
    //Azure
//    private let baseURL = "https://my-ielts-practice-backend-atf0g2eqg6f5byc9.westeurope-01.azurewebsites.net/"
    
    
    /// This is the correct URL for the server that is running
//    private let baseURL = ""
    
    let baseURL = URL(string: "https://ielts-api.azurewebsites.net")!

    
//    private let baseURL = "http://10.194.61.227:8000"
//    private let baseURL = "http://10.68.96.80:'8000"
//    private let baseURL = "http://192.168.208.227:8000"
    // Use this for a real device, replacing with your Mac's Wi-Fi IP
    // private let baseURL = "http://YOUR_MACS_IP_ADDRESS:8000"

    private init() {}
    
    func fetchConversations() async -> Result<[ConversationDTO], Error> {
        guard let token = KeychainManager.shared.getToken() else { return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/conversations") else { return .failure(NetworkError.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(NetworkError.invalidResponse)
            }
            
            // Handle empty response gracefully
            if data.isEmpty {
                print("ℹ️ Server returned empty response for conversations")
                return .success([])
            }
            
            // Check if response is valid JSON
            guard data.count > 0 else {
                print("ℹ️ No conversation data available")
                return .success([])
            }
            
            do {
            let conversations = try JSONDecoder().decode([ConversationDTO].self, from: data)
            return .success(conversations)
            } catch let decodingError {
                print("❌ JSON decoding error: \(decodingError)")
                // Return empty array instead of failing completely
                return .success([])
            }
        } catch {
            print("❌ Network request error: \(error)")
            return .failure(error)
        }
    }
    
    func saveConversation(_ payload: ConversationPayload) async -> Result<ConversationDTO, Error> {
        guard let token = KeychainManager.shared.getToken() else { return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/conversations") else { return .failure(NetworkError.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
            let savedConversation = try JSONDecoder().decode(ConversationDTO.self, from: data)
            return .success(savedConversation)
        } catch {
            return .failure(error)
        }
    }
    
    // В файле NetworkManager.swift, внутри класса

    func changePassword(current: String, new: String) async -> Result<Void, Error> {
        guard let token = KeychainManager.shared.getToken() else { return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/users/me/password") else { return .failure(NetworkError.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "current_password": current,
            "new_password": new
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            if httpResponse.statusCode == 200 {
                return .success(())
            } else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
        } catch {
            return .failure(error)
        }
    }
    
    func deleteBackendConversation(serverId: Int) async -> Result<Void, Error> {
        guard let token = KeychainManager.shared.getToken() else { return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/conversations/\(serverId)") else { return .failure(NetworkError.invalidURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(NetworkError.invalidResponse)
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    // В файле NetworkManager.swift

    func getFinalFeedback(for conversation: [QuestionAnswerPairDTO], token: String) async -> Result<FeedbackResponse, Error> {
        guard let url = URL(string: "\(baseURL)/practice/final-feedback") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let payload = ["conversation": conversation]
        request.httpBody = try? JSONEncoder().encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
            
            let feedbackResponse = try JSONDecoder().decode(FeedbackResponse.self, from: data)
            return .success(feedbackResponse)
        } catch {
            return .failure(error)
        }
    }
    
    // Enhanced feedback function with additional metadata for better scoring
    func getFinalFeedbackEnhanced(payload: EnhancedFeedbackPayload, token: String) async -> Result<FeedbackResponse, Error> {
        guard let url = URL(string: "\(baseURL)/practice/final-feedback-enhanced") else {
            // Fallback to regular endpoint if enhanced endpoint doesn't exist
            return await getFinalFeedback(for: payload.conversation, token: token)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("❌ Failed to encode enhanced payload: \(error)")
            return .failure(NetworkError.encodingError("Failed to encode enhanced payload"))
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            if httpResponse.statusCode == 404 {
                // Enhanced endpoint not available, fallback to regular endpoint
                print("ℹ️ Enhanced feedback endpoint not available, using standard endpoint")
                return await getFinalFeedback(for: payload.conversation, token: token)
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
            
            let feedbackResponse = try JSONDecoder().decode(FeedbackResponse.self, from: data)
            return .success(feedbackResponse)
        } catch {
            print("❌ Enhanced feedback request failed, falling back to standard endpoint: \(error)")
            // Fallback to regular endpoint on any error
            return await getFinalFeedback(for: payload.conversation, token: token)
        }
    }

    // Add this new function inside the NetworkManager class
    func verifyCode(email: String, code: String) async -> Result<Token, Error> {
        guard let url = URL(string: "\(baseURL)/verify") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
            
            let tokenResponse = try JSONDecoder().decode(Token.self, from: data)
            return .success(tokenResponse)
        } catch {
            return .failure(error)
        }
    }
    
    // Add this function inside your NetworkManager class
    func fetchPart1Questions() async -> Result<[String], Error> {
        guard let url = URL(string: "\(baseURL)/part1-questions") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(NetworkError.invalidResponse)
            }
            let questions = try JSONDecoder().decode([String].self, from: data)
            return .success(questions)
        } catch {
            return .failure(error)
        }
    }

    // In NetworkManager.swift

    func register(email: String, password: String, name: String? = nil) async -> Result<String, Error> {
        print("🔐 NetworkManager: Attempting registration for email: \(email)")
        print("🌐 NetworkManager: Using base URL: \(baseURL)")
        
        guard let url = URL(string: "\(baseURL)/register") else {
            print("❌ NetworkManager: Invalid URL for registration")
            return .failure(NetworkError.invalidURL)
        }
        
        print("📡 NetworkManager: Sending registration request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["email": email, "password": password]
        if let name = name {
            body["name"] = name
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ NetworkManager: Invalid HTTP response for registration")
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Registration response status code: \(httpResponse.statusCode)")
            let responseText = String(data: data, encoding: .utf8) ?? "Empty response"
            print("📄 NetworkManager: Registration response body: \(responseText)")
            
            if httpResponse.statusCode == 201 {
                do {
                    let successResponse = try JSONDecoder().decode(RegistrationResponse.self, from: data)
                    print("✅ NetworkManager: Registration successful with message: \(successResponse.message)")
                    return .success(successResponse.message)
                } catch {
                    print("⚠️ NetworkManager: Could not decode success response, using default message")
                    return .success("Verification code sent.")
                }
            } else if httpResponse.statusCode == 409 {
                print("⚠️ NetworkManager: Email conflict (409) - account exists and is verified")
                // Handle case where email already exists and is verified
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    print("📄 NetworkManager: Error detail: \(errorDetail.detail)")
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    return .failure(NetworkError.serverError("User with this email already exists. Please log in instead."))
                }
            } else {
                print("❌ NetworkManager: Registration failed with status \(httpResponse.statusCode)")
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    print("📄 NetworkManager: Error detail: \(errorDetail.detail)")
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    print("❌ NetworkManager: Could not decode error response")
                    return .failure(NetworkError.serverError("Registration failed with status \(httpResponse.statusCode): \(responseText)"))
                }
            }
        } catch {
            print("❌ NetworkManager: Network error during registration: \(error)")
            return .failure(error)
        }
    }
    
    // Add function to resend verification code for existing unverified accounts
    func resendVerificationCode(email: String) async -> Result<String, Error> {
        print("🔐 NetworkManager: Resending verification code for email: \(email)")
        
        guard let url = URL(string: "\(baseURL)/resend-verification") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Resend verification response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    let successResponse = try JSONDecoder().decode(RegistrationResponse.self, from: data)
                    print("✅ NetworkManager: Verification code resent successfully")
                    return .success(successResponse.message)
                } catch {
                    return .success("Verification code sent.")
                }
            } else if httpResponse.statusCode == 404 {
                // Handle account not found specifically
                print("⚠️ NetworkManager: Account not found (404) for resend verification")
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    return .failure(NetworkError.serverError("Account with this email does not exist."))
                }
            } else {
                let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ NetworkManager: Resend verification failed (\(httpResponse.statusCode)): \(responseText)")
                
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    return .failure(NetworkError.serverError("Failed to resend verification code."))
                }
            }
        } catch {
            print("❌ NetworkManager: Network error during resend verification: \(error)")
            return .failure(error)
        }
    }
    
    func login(email: String, password: String) async -> Result<String, Error> {
        print("🔐 NetworkManager: Attempting login for email: \(email)")
        
        guard let url = URL(string: "\(baseURL)/token") else { return .failure(NetworkError.invalidURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Login response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(Token.self, from: data)
                print("✅ NetworkManager: Login successful")
                return .success(tokenResponse.access_token)
            } else {
                let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ NetworkManager: Login failed (\(httpResponse.statusCode)): \(responseText)")
                
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    // Pass through the exact backend error message
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    // Default error for authentication failure
                    return .failure(NetworkError.serverError("Login failed. Please try again."))
                }
            }
        } catch {
            print("❌ NetworkManager: Network error during login: \(error)")
            return .failure(error)
        }
    }
    
    func fetchCurrentUser() async -> Result<UserOut, Error> {
        guard let token = KeychainManager.shared.getToken() else { return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/users/me") else { return .failure(NetworkError.invalidURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(NetworkError.invalidResponse)
            }
            let user = try JSONDecoder().decode(UserOut.self, from: data)
            return .success(user)
        } catch { return .failure(error) }
    }


    // In NetworkManager.swift

    // Add these two new functions inside the NetworkManager class
    
    // In NetworkManager.swift

    // In NetworkManager.swift

    func fetchSpeech(for text: String, voice: VoiceChoice) async -> Result<Data, Error> {
        guard let url = URL(string: "\(baseURL)/text-to-speech") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 👇 Now we send both text and the selected voice
        let body: [String: String] = [
            "text": text,
            "voice": voice.rawValue
        ]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(NetworkError.invalidResponse)
            }
            
            return .success(data)
        } catch {
            return .failure(error)
        }
    }

    
    // В файле NetworkManager.swift

    func requestPasswordReset(email: String) async -> Result<String, Error> {
        print("🔐 NetworkManager: Requesting password reset for email: \(email)")
        print("🌐 NetworkManager: Using base URL: \(baseURL)")
        
        guard let url = URL(string: "\(baseURL)/send-reset-code") else {
            print("❌ NetworkManager: Invalid URL")
            return .failure(NetworkError.invalidURL)
        }
        
        print("📡 NetworkManager: Sending request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ NetworkManager: Invalid HTTP response")
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Response status code: \(httpResponse.statusCode)")
            let responseText = String(data: data, encoding: .utf8) ?? "Empty response"
            print("📄 NetworkManager: Response body: \(responseText)")
            
            if httpResponse.statusCode == 200 {
                print("✅ NetworkManager: Success response")
                
                if let successResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = successResponse["message"] {
                    return .success(message)
                }
                return .success("Password reset code sent successfully.")
            } else if httpResponse.statusCode == 404 {
                // Handle account not found specifically
                print("⚠️ NetworkManager: Account not found (404)")
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    return .failure(NetworkError.serverError("Account with this email does not exist."))
                }
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ NetworkManager: Error response (\(httpResponse.statusCode)): \(errorText)")
                
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                } else {
                    return .failure(NetworkError.serverError("Server error (Status: \(httpResponse.statusCode)): \(errorText)"))
                }
            }
        } catch {
            print("❌ NetworkManager: Network error: \(error)")
            return .failure(error)
        }
    }
    
    func verifyResetCode(email: String, code: String) async -> Result<Token, Error> {
        print("🔐 NetworkManager: Verifying reset code for email: \(email)")
        
        guard let url = URL(string: "\(baseURL)/verify") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Set 30 second timeout
        
        let body = ["email": email, "code": code, "type": "reset"]
        print("📤 NetworkManager: Sending request with body: \(body)")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Response status code: \(httpResponse.statusCode)")
            let responseText = String(data: data, encoding: .utf8) ?? "Empty response"
            print("📄 NetworkManager: Response body: \(responseText)")
            
            // Success case: 200 or 201 status codes
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("✅ NetworkManager: Code verification successful")
                // Parse the token from response
                if let tokenResponse = try? JSONDecoder().decode(Token.self, from: data) {
                    return .success(tokenResponse)
                }
                return .failure(NetworkError.decodingError("Failed to decode token response"))
            }
            
            // Try to decode error response
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 NetworkManager: Decoded JSON response: \(jsonResponse)")
                
                // Check for error messages
                if let detail = jsonResponse["detail"] as? String {
                    print("❌ NetworkManager: Server error: \(detail)")
                    if detail.lowercased().contains("not found") ||
                       detail.lowercased().contains("invalid") ||
                       detail.lowercased().contains("incorrect") {
                        return .failure(NetworkError.serverError("The code is not correct"))
                    }
                    return .failure(NetworkError.serverError(detail))
                }
                
                if let message = jsonResponse["message"] as? String {
                    print("❌ NetworkManager: Server message: \(message)")
                    if message.lowercased().contains("not found") ||
                       message.lowercased().contains("invalid") ||
                       message.lowercased().contains("incorrect") {
                        return .failure(NetworkError.serverError("The code is not correct"))
                    }
                    return .failure(NetworkError.serverError(message))
                }
            }
            
            // Default error case
            return .failure(NetworkError.serverError("The code is not correct"))
            
        } catch let error as URLError {
            print("❌ NetworkManager: URLError: \(error.localizedDescription)")
            
            switch error.code {
            case .notConnectedToInternet:
                return .failure(NetworkError.connectionError("No internet connection. Please check your connection and try again."))
            case .timedOut:
                return .failure(NetworkError.connectionError("Connection timed out. Please try again."))
            case .networkConnectionLost:
                return .failure(NetworkError.connectionError("Connection lost. Please try again."))
            default:
                return .failure(NetworkError.networkError("Network error. Please try again."))
            }
        } catch {
            print("❌ NetworkManager: Error verifying reset code: \(error)")
            return .failure(NetworkError.networkError("Unexpected error. Please try again."))
        }
    }
    
    func confirmPasswordReset(newPassword: String, token: String) async -> Result<String, Error> {
        print("🔐 NetworkManager: Confirming password reset with token")
        
        guard let url = URL(string: "\(baseURL)/reset-password") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["new_password": newPassword]
        print("📤 NetworkManager: Sending password reset request with body: \(body)")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse)
            }
            
            print("📊 NetworkManager: Password reset response status code: \(httpResponse.statusCode)")
            let responseText = String(data: data, encoding: .utf8) ?? "Empty response"
            print("📄 NetworkManager: Response body: \(responseText)")
            
            if httpResponse.statusCode == 200 {
                if let successResponse = try? JSONDecoder().decode(RegistrationResponse.self, from: data) {
                    print("✅ NetworkManager: Password reset successful with message: \(successResponse.message)")
                    return .success(successResponse.message)
                }
                return .success("Your password has been successfully reset.")
            }
            
            // Handle error responses
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                print("❌ NetworkManager: Server error: \(errorDetail.detail)")
                    return .failure(NetworkError.serverError(errorDetail.detail))
            }
            
            print("❌ NetworkManager: Unexpected error response")
            return .failure(NetworkError.serverError("Failed to reset password. Please try again."))
        } catch {
            print("❌ NetworkManager: Network error during password reset: \(error)")
            return .failure(error)
        }
    }
    
    // --- NEW FUNCTION: Update User Profile ---
    func updateUserProfile(name: String) async -> Result<UserOut, Error> {
        guard let token = KeychainManager.shared.getToken() else {
            return .failure(NetworkError.unauthorized)
        }
        
        guard let url = URL(string: "\(baseURL)/users/me") else {
            return .failure(NetworkError.invalidURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["name": name]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let errorDetail = try? JSONDecoder().decode(ErrorDetail.self, from: data) {
                    return .failure(NetworkError.serverError(errorDetail.detail))
                }
                return .failure(NetworkError.invalidResponse)
            }
            
            let updatedUser = try JSONDecoder().decode(UserOut.self, from: data)
            return .success(updatedUser)
        } catch {
            return .failure(error)
        }
    }

    // --- NEW FUNCTION: Delete Account ---
    func deleteAccount() async -> Result<Void, Error> {
        print("[NetworkManager] deleteAccount called")
        guard let token = KeychainManager.shared.getToken() else { print("[NetworkManager] No token"); return .failure(NetworkError.unauthorized) }
        guard let url = URL(string: "\(baseURL)/users/me") else { print("[NetworkManager] Invalid URL"); return .failure(NetworkError.invalidURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[NetworkManager] Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("[NetworkManager] Delete succeeded")
                    return .success(())
                } else {
                    print("[NetworkManager] Delete failed, status: \(httpResponse.statusCode)")
                    return .failure(NetworkError.invalidResponse)
                }
            } else {
                print("[NetworkManager] No HTTPURLResponse")
                return .failure(NetworkError.invalidResponse)
            }
        } catch {
            print("[NetworkManager] Delete error: \(error)")
            return .failure(error)
        }
    }
    

    
}

struct ErrorDetail: Codable {
    let detail: String
}

struct RegistrationResponse: Codable {
    let message: String
}

struct UserOut: Codable {
    let id: Int
    let email: String
    let name: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        
        // Handle date decoding with a custom format
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString)
        } else {
            createdAt = nil
        }
    }
}

struct Token: Codable {
    let access_token: String
    let token_type: String
}

// In NetworkManager.swift

struct SentenceFeedback: Codable {
    let sentence: String
    let feedback: String
    let suggestion: String
}

struct AnswerAnalysis: Codable {
    let question: String
    let answer: String
    let grammarFeedback: [SentenceFeedback]
    let vocabularyFeedback: [SentenceFeedback]
    let fluencyFeedback: String

    enum CodingKeys: String, CodingKey {
        case question, answer
        case grammarFeedback = "grammar_feedback"
        case vocabularyFeedback = "vocabulary_feedback"
        case fluencyFeedback = "fluency_feedback"
    }
}

// Our new main response model
struct FeedbackResponse: Codable {
    let overallBandScore: Double
    let fluencyScore: Int
    let lexicalScore: Int
    let grammarScore: Int
    let pronunciationScore: Int
    let generalSummary: String
    let answerAnalyses: [AnswerAnalysis]

    enum CodingKeys: String, CodingKey {
        case overallBandScore = "overall_band_score"
        case fluencyScore = "fluency_score"
        case lexicalScore = "lexical_score"
        case grammarScore = "grammar_score"
        case pronunciationScore = "pronunciation_score"
        case generalSummary = "general_summary"
        case answerAnalyses = "answer_analyses"
    }
}

struct QuestionAnswerPair: Codable {
    let question: String
    let answer: String
}
