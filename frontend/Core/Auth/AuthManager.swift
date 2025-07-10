import Foundation
import Combine
import SwiftUI

// MARK: - Error Models
struct AppError: Identifiable {
    let id = UUID()
    let message: String
    let isSuccess: Bool
    
    init(message: String, isSuccess: Bool = false) {
        self.message = message
        self.isSuccess = isSuccess
    }
}

extension Notification.Name {
    static let userWillLogout = Notification.Name("userWillLogout")
}

typealias UserDetails = UserOut

extension DateFormatter {
    var dateFormats: [String] {
        get { return [] }
        set {
            self.dateFormat = newValue.first
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Notification Names
    static let userDidLogoutNotification = Notification.Name("userDidLogout")
    
    // MARK: - Published Properties
    @Published var isLoggedIn: Bool = false
    @Published var userDetails: UserDetails?
    @Published var appError: AppError? = nil
    
    // Этот флаг будет управлять экраном загрузки при запуске
    @Published var isValidatingSession: Bool = true
    @Published var isLoading: Bool = false
    
    // Эти свойства управляют навигацией для верификации и сброса пароля
    @Published var emailForVerification: String?
    @Published var emailForPasswordReset: String?
    @Published var showingForgotPasswordSheet = false
    
    // Это свойство будет хранить email текущего пользователя для SwiftData
    @AppStorage("currentUserEmail") private var currentUserEmail: String = ""

    // Add property to store reset verification token
    @Published private var resetVerificationToken: String?

    // MARK: - Private Properties
    private var token: String? {
        didSet {
            // Обновляем состояние isLoggedIn только при изменении токена
            isLoggedIn = token != nil
        }
    }
    
    private let keychainManager = KeychainManager.shared
    private let networkManager = NetworkManager.shared
    
    // MARK: - Initialization
    init() {
        print("🔄 AuthManager: Initializing...")
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        print("🔍 AuthManager: Checking existing session...")
        
        if let token = keychainManager.getToken() {
            Task {
                await validateSession(token)
            }
        } else {
            print("❌ AuthManager: Token not found. User not authenticated.")
            isLoggedIn = false
            isValidatingSession = false
        }
    }
    
    @MainActor
    private func validateSession(_ token: String) async {
        print("🔍 AuthManager: Validating session...")
        
        let result = await networkManager.fetchCurrentUser()
        
        switch result {
        case .success(let user):
            userDetails = user
            isLoggedIn = true
            print("✅ AuthManager: Session validated successfully.")
            
        case .failure(let error):
            print("❌ AuthManager: Session validation failed: \(error)")
            forceLogout()
        }
        
        isValidatingSession = false
    }
    
    // MARK: - Authentication Flows
    
    @MainActor
    func login(email: String, password: String) async {
        print("🔐 AuthManager: Attempting login for \(email)...")
        isValidatingSession = true
        
        switch await networkManager.login(email: email, password: password) {
        case .success(let token):
            keychainManager.save(token: token)
            isLoggedIn = true
            
            // Fetch user details after successful login
            let userResult = await networkManager.fetchCurrentUser()
            if case .success(let user) = userResult {
                userDetails = user
            }
            
            print("✅ AuthManager: Login successful for \(email)")
            
        case .failure(let error):
            print("❌ AuthManager: Login failed: \(error)")
            handleError(error)
        }
        
        isValidatingSession = false
    }
    
    /// Регистрация нового пользователя.
    func register(email: String, password: String, name: String? = nil) async {
        isLoading = true
        appError = nil
        
        let result = await NetworkManager.shared.register(email: email, password: password, name: name)
        
        isLoading = false
        
        switch result {
        case .success(let message):
            // Always proceed to verification screen on success
            // This handles both new registrations and resent codes for unverified accounts
            self.emailForVerification = email
            self.appError = AppError(message: message, isSuccess: true)
        case .failure(let error):
            // Handle specific case of verified existing account
            if let networkError = error as? NetworkError,
               case .serverError(let detail) = networkError,
               detail.lowercased().contains("already exists and is verified") {
                self.appError = AppError(message: "This email is already registered. Please log in instead.")
            } else {
                handleError(error)
            }
        }
    }
    
    /// Resend verification code for existing unverified account.
    func resendVerificationCode() async {
        guard let email = emailForVerification else { return }
        
        isLoading = true
        appError = nil
        
        let result = await NetworkManager.shared.resendVerificationCode(email: email)
        
        isLoading = false
        
        switch result {
        case .success(let message):
            self.appError = AppError(message: message, isSuccess: true)
        case .failure(let error):
            // Check if it's an account not found error
            if let networkError = error as? NetworkError,
               case .serverError(let detail) = networkError,
               detail.lowercased().contains("does not exist") {
                self.appError = AppError(message: "Account with this email does not exist. Please register first.")
                // Reset verification flow since account doesn't exist
                self.emailForVerification = nil
            } else {
                handleError(error)
            }
        }
    }

    @MainActor
    func logout() {
        print("🚪 AuthManager: Logging out...")
        NotificationCenter.default.post(name: .userWillLogout, object: nil)
        
        keychainManager.deleteToken()
        isLoggedIn = false
        userDetails = nil
        
        print("✅ AuthManager: Logout complete")
    }
    
    /// Forced logout (used when token expires).
    private func forceLogout() {
        // This function executes the same as regular logout,
        // but also shows an alert to the user
        Task { @MainActor in
            logout()
        }
    }
    
    // MARK: - Account Verification
    
    func verifyAccount(code: String) async {
        guard let email = emailForVerification else { return }
        
        appError = nil
        isLoading = true
        
        let result = await NetworkManager.shared.verifyCode(email: email, code: code)
        
        isLoading = false
        
        switch result {
        case .success(let tokenResponse):
            // После успешной верификации пользователь сразу входит в систему
            KeychainManager.shared.save(token: tokenResponse.access_token)
            self.token = tokenResponse.access_token
            self.emailForVerification = nil // Сбрасываем email для верификации
            await fetchUserDetails() // Загружаем данные
        case .failure(let error):
            handleError(error)
        }
    }
    
    func cancelVerification() {
        self.emailForVerification = nil
        self.appError = nil
    }
    
    // MARK: - Password Reset
    
    func requestPasswordReset(email: String) async {
        appError = nil
        isLoading = true
        resetVerificationToken = nil // Clear any existing verification token
        
        let result = await NetworkManager.shared.requestPasswordReset(email: email)
        
        isLoading = false
        
        switch result {
        case .success(let message):
            self.emailForPasswordReset = email
            self.showingForgotPasswordSheet = false
            self.appError = AppError(message: message, isSuccess: true)
        case .failure(let error):
            // Check if it's an account not found error
            if let networkError = error as? NetworkError,
               case .serverError(let detail) = networkError,
               detail.lowercased().contains("does not exist") {
                self.appError = AppError(message: "Account with this email does not exist. Would you like to create a new account instead?")
            } else {
                handleError(error)
            }
        }
    }

    func verifyResetCode(code: String) async -> Bool {
        guard let email = emailForPasswordReset else {
            appError = AppError(message: "Session expired. Please try again.")
            return false
        }
        
        appError = nil
        isLoading = true
        
        let result = await NetworkManager.shared.verifyResetCode(email: email, code: code)
        
        isLoading = false
        
        switch result {
        case .success(let tokenResponse):
            print("✅ AuthManager: Code verification successful")
            // Store the verification token for later use
            resetVerificationToken = tokenResponse.access_token
            appError = nil
            return true
            
        case .failure(let error):
            print("❌ AuthManager: Code verification failed: \(error)")
            if let networkError = error as? NetworkError {
                switch networkError {
                case .serverError(let message):
                    // For connection-related errors, show the exact message
                    if message.contains("internet") || message.contains("connection") || message.contains("timed out") {
                        appError = AppError(message: message)
                    } else {
                        // For validation errors, show "The code is not correct"
                        appError = AppError(message: "The code is not correct.")
                    }
                case .invalidURL:
                    appError = AppError(message: "Invalid request. Please try again.")
                case .invalidResponse:
                    appError = AppError(message: "Invalid response from server. Please try again.")
                case .unauthorized:
                    appError = AppError(message: "Session expired. Please try again.")
                case .decodingError(let message):
                    appError = AppError(message: "Error processing response: \(message)")
                case .encodingError(let message):
                    appError = AppError(message: "Error preparing request: \(message)")
                case .noData:
                    appError = AppError(message: "No data received. Please try again.")
                case .networkError(let message):
                    appError = AppError(message: message)
                case .connectionError(let message):
                    appError = AppError(message: message)
                }
            } else {
                appError = AppError(message: "Network error. Please try again.")
            }
            resetVerificationToken = nil // Clear token on failure
            return false
        }
    }

    // In AuthManager.swift

    func confirmPasswordReset(newPassword: String) async {
        guard let token = resetVerificationToken else {
            appError = AppError(message: "Verification expired. Please verify the code again.")
            return
        }
        
        appError = nil
        isLoading = true
        
        let result = await NetworkManager.shared.confirmPasswordReset(newPassword: newPassword, token: token)
        
        isLoading = false
        
        switch result {
        case .success(let message):
            self.emailForPasswordReset = nil
            self.resetVerificationToken = nil // Очищаем токен после успешного сброса
            self.appError = AppError(message: message, isSuccess: true)
        case .failure(let error):
            if let networkError = error as? NetworkError,
               case .serverError(let detail) = networkError {
                if detail.lowercased().contains("invalid") || detail.lowercased().contains("expired") {
                    self.appError = AppError(message: "Invalid or expired reset code.")
                    // Сбрасываем состояние верификации, так как код недействителен/истек
                    self.resetVerificationToken = nil
                } else {
                    self.appError = AppError(message: detail)
                }
            } else {
                handleError(error)
            }
        }
    }
    
    func cancelPasswordReset() {
        self.emailForPasswordReset = nil
        self.resetVerificationToken = nil
        self.appError = nil
    }

    // MARK: - User Account Management
    
    func updateProfile(name: String) async {
        isLoading = true
        let result = await NetworkManager.shared.updateUserProfile(name: name)
        isLoading = false
        
        switch result {
        case .success(let updatedUser):
            self.userDetails = updatedUser
            print("✅ AuthManager: Profile updated successfully")
        case .failure(let error):
            handleError(error)
        }
    }
    
    func deleteAccount() async {
        isLoading = true
        let result = await NetworkManager.shared.deleteAccount()
        isLoading = false
        
        if case .success = result {
            print("✅ AuthManager: Аккаунт успешно удален на сервере. Выполняется выход.")
            logout()
        } else if case .failure(let error) = result {
            handleError(error)
        }
    }

    // MARK: - Helpers
    
    /// Загружает данные пользователя с сервера после успешного входа или верификации.
    private func fetchUserDetails() async {
        let result = await NetworkManager.shared.fetchCurrentUser()
        
        if case .success(let user) = result {
            self.userDetails = user
            self.currentUserEmail = user.email
            print("✅ AuthManager: Данные пользователя загружены для \(user.email).")
        } else {
            print("❌ AuthManager: Не удалось загрузить данные пользователя после входа.")
            await forceLogout()
        }
    }
    
    /// Обрабатывает ошибки сети и преобразует их в `AppError` для отображения в UI.
    private func handleError(_ error: Error) {
        print("🔍 AuthManager: Handling error: \(error)")
        
        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError(let message):
                print("🔍 AuthManager: Server error: \(message)")
                self.appError = AppError(message: message)
            case .unauthorized:
                print("🔍 AuthManager: Unauthorized access")
                self.appError = AppError(message: "Session expired. Please log in again.")
            case .invalidURL:
                print("🔍 AuthManager: Invalid URL error")
                self.appError = AppError(message: "Invalid request. Please try again.")
            case .invalidResponse:
                print("🔍 AuthManager: Invalid response error")
                self.appError = AppError(message: "Invalid response from server. Please try again.")
            case .decodingError(let detail):
                print("🔍 AuthManager: Decoding error: \(detail)")
                self.appError = AppError(message: "Error processing response: \(detail)")
            case .encodingError(let detail):
                print("🔍 AuthManager: Encoding error: \(detail)")
                self.appError = AppError(message: "Error preparing request: \(detail)")
            case .noData:
                print("🔍 AuthManager: No data received")
                self.appError = AppError(message: "No data received. Please try again.")
            case .networkError(let detail):
                print("🔍 AuthManager: Network error: \(detail)")
                self.appError = AppError(message: detail)
            case .connectionError(let detail):
                print("🔍 AuthManager: Connection error: \(detail)")
                self.appError = AppError(message: detail)
            }
        } else {
            print("🔍 AuthManager: Generic error: \(error.localizedDescription)")
            self.appError = AppError(message: error.localizedDescription)
        }
    }
}
