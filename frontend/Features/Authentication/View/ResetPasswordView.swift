import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    let email: String
    
    @State private var verificationCode = ""
    @State private var newPassword: String = ""
    @State private var isPasswordVisible = false
    @State private var errorFlash = false
    @State private var showContent = false
    @State private var showCursor = true
    @State private var canResend = false
    @State private var resendCountdown = 60
    @State private var resendTimer: Timer?
    @State private var isVerificationStep = true
    @State private var isCodeVerified = false
    @State private var verifiedCode: String?
    @FocusState private var isCodeFieldFocused: Bool
    
    private let codeLength = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Beautiful purple gradient background (matching registration)
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.8),
                        Color.indigo.opacity(0.7),
                        Color.purple.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Static background particles (no animation during focus)
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 80 + CGFloat(index * 20))
                        .position(
                            x: geometry.size.width * (0.2 + Double(index) * 0.2),
                            y: geometry.size.height * (0.3 + Double(index) * 0.15)
                        )
                        .blur(radius: 3)
                        .scaleEffect(showContent ? 1.0 : 0.8)
                        .opacity(showContent ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 1.0).delay(Double(index) * 0.2), value: showContent)
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Top spacing
                        Spacer()
                            .frame(height: geometry.size.height * 0.15)
                        
                        // Main content
                        VStack(spacing: 32) {
                            // Header section
                            VStack(spacing: 20) {
                                // Reset password icon with animation
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "lock.rotation")
                                        .font(.system(size: 50, weight: .light))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(showContent ? 1.0 : 0.5)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showContent)
                                
                                VStack(spacing: 12) {
                                    Text("Reset Your Password")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    VStack(spacing: 8) {
                                        Text("We've sent a 6-digit verification code to:")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .multilineTextAlignment(.center)
                                        
                                        Text(email)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.2))
                                            )
                                    }
                                }
                                .opacity(showContent ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 0.8).delay(0.3), value: showContent)
                            }
                            
                            // Form section
                            VStack(spacing: 24) {
                                // Error message
                                if let error = authManager.appError {
                                    HStack {
                                        Image(systemName: error.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(error.isSuccess ? .green : .red)
                                        Text(error.message)
                                            .font(.caption)
                                            .foregroundColor(error.isSuccess ? .green : .red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.9))
                                    )
                                    .scaleEffect(errorFlash ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: errorFlash)
                                    .onChange(of: error.message) { _ in
                                        withAnimation {
                                            errorFlash.toggle()
                                        }
                                    }
                                }
                                
                                if isVerificationStep {
                                    // Code input field
                                    VStack(spacing: 16) {
                                        Text("Enter verification code")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        // Custom code input with individual boxes
                                        HStack(spacing: 12) {
                                            ForEach(0..<codeLength, id: \.self) { index in
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.white.opacity(0.9))
                                                        .frame(width: 45, height: 55)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(
                                                                    getCurrentBoxBorderColor(for: index),
                                                                    lineWidth: getCurrentBoxBorderWidth(for: index)
                                                                )
                                                        )
                                                    
                                                    // Show digit or cursor
                                                    if verificationCode.count > index {
                                                        Text(getDigit(at: index))
                                                            .font(.title)
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(.black)
                                                    } else if verificationCode.count == index && isCodeFieldFocused {
                                                        // Show blinking cursor in the current box
                                                        Rectangle()
                                                            .fill(Color.purple)
                                                            .frame(width: 2, height: 30)
                                                            .opacity(showCursor ? 1.0 : 0.0)
                                                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showCursor)
                                                    }
                                                }
                                                .onTapGesture {
                                                    isCodeFieldFocused = true
                                                }
                                            }
                                        }
                                        .background(
                                            // Hidden text field for keyboard input
                                            TextField("", text: $verificationCode)
                                                .keyboardType(.numberPad)
                                                .textContentType(.oneTimeCode)
                                                .foregroundColor(.clear)
                                                .accentColor(.clear)
                                                .background(Color.clear)
                                                .focused($isCodeFieldFocused)
                                                .onChange(of: verificationCode) { newValue in
                                                    // Only allow numbers and limit to 6 digits
                                                    let filtered = newValue.filter { $0.isNumber }
                                                    if filtered.count > codeLength {
                                                        verificationCode = String(filtered.prefix(codeLength))
                                                    } else {
                                                        verificationCode = filtered
                                                    }
                                                }
                                                .opacity(0.01)
                                        )
                                        
                                        // Instruction text
                                        Text(isCodeFieldFocused ? "Enter the 6-digit code" : "Tap above to enter code")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                            .animation(.easeInOut(duration: 0.3), value: isCodeFieldFocused)
                                        
                                        // Continue Button
                                        Button(action: verifyCode) {
                                            HStack {
                                                if authManager.isLoading {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .scaleEffect(0.8)
                                                } else {
                                                    Image(systemName: "arrow.right.circle.fill")
                                                        .font(.title3)
                                                }
                                                
                                                Text(authManager.isLoading ? "Verifying..." : "Continue")
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.purple, Color.indigo],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                            )
                                        }
                                        .disabled(authManager.isLoading || verificationCode.count != codeLength)
                                        .opacity(verificationCode.count == codeLength ? 1.0 : 0.6)
                                        .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: authManager.isLoading)
                                        
                                        // Resend code section
                                        VStack(spacing: 12) {
                                            if canResend {
                                                Button("Resend verification code") {
                                                    resendCode()
                                                }
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.white.opacity(0.2))
                                                )
                                            } else {
                                                Text("Resend code in \(resendCountdown) seconds")
                                                    .font(.subheadline)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                } else {
                                    // New password field
                                    VStack(spacing: 16) {
                                        Text("Choose new password")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        HStack {
                                            Image(systemName: "lock")
                                                .foregroundColor(.gray)
                                                .frame(width: 20)
                                            
                                            if isPasswordVisible {
                                                NoSelectTextFieldStyle(
                                                    text: $newPassword,
                                                    placeholder: "New Password"
                                                )
                                                .frame(maxWidth: .infinity)
                                            } else {
                                                NoSelectTextFieldStyle(
                                                    text: $newPassword,
                                                    placeholder: "New Password",
                                                    isSecure: true
                                                )
                                                .frame(maxWidth: .infinity)
                                            }
                                            
                                            Button(action: { isPasswordVisible.toggle() }) {
                                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.9))
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // This ensures the entire field area is tappable
                                        }
                                        .onChange(of: newPassword) { newValue in
                                            // Limit password to 30 characters
                                            if newValue.count > 30 {
                                                newPassword = String(newValue.prefix(30))
                                            }
                                        }
                                        
                                        // Password requirements - always show when password field has content
                                        if !newPassword.isEmpty {
                                            PasswordRequirementsView(password: newPassword)
                                                .padding(.top, 8)
                                        }
                                        
                                        // Set new password button
                                        Button(action: setNewPassword) {
                                            HStack {
                                                if authManager.isLoading {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .scaleEffect(0.8)
                                                } else {
                                                    Image(systemName: "checkmark.shield.fill")
                                                        .font(.title3)
                                                }
                                                
                                                Text(authManager.isLoading ? "Setting Password..." : "Set New Password")
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 56)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color.purple, Color.indigo],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                                            )
                                        }
                                        .disabled(authManager.isLoading || !isPasswordValid)
                                        .opacity(isPasswordValid ? 1.0 : 0.6)
                                        .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: authManager.isLoading)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            
                            Spacer()
                            
                            // Back button
                            Button("← Go Back") {
                                if !isVerificationStep {
                                    withAnimation {
                                        isVerificationStep = true
                                        // Keep the verified code if it exists
                                        if let code = verifiedCode {
                                            verificationCode = code
                                        }
                                    }
                                } else {
                                    authManager.cancelPasswordReset()
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Bottom spacing
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showContent = true
            }
            startResendTimer()
            
            // Auto-focus the code field after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isCodeFieldFocused = true
            }
            
            // Start cursor blinking animation
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                showCursor = true
            }
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var isPasswordValid: Bool {
        PasswordValidator.validate(newPassword).isValid
    }
    
    private func getDigit(at index: Int) -> String {
        guard index < verificationCode.count else { return "" }
        return String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
    }
    
    private func getCurrentBoxBorderColor(for index: Int) -> Color {
        if verificationCode.count > index {
            return Color.purple
        } else if verificationCode.count == index && isCodeFieldFocused {
            return Color.purple
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func getCurrentBoxBorderWidth(for index: Int) -> CGFloat {
        if verificationCode.count > index {
            return 2
        } else if verificationCode.count == index && isCodeFieldFocused {
            return 3
        } else {
            return 1
        }
    }
    
    // In ResetPasswordView.swift

    private func verifyCode() {
        // Валидация ввода остается прежней
        if verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Verification code cannot be empty.")
            return
        }
        
        if verificationCode.count != codeLength {
            authManager.appError = AppError(message: "Please enter the complete 6-digit code.")
            return
        }
        
        // Вызываем AuthManager вместо прямого вызова NetworkManager
        Task {
            let success = await authManager.verifyResetCode(code: verificationCode)
            
            if success {
                print("✅ ResetPasswordView: Верификация через AuthManager прошла успешно, переходим к сбросу пароля")
                withAnimation { isVerificationStep = false }
            } else {
                print("❌ ResetPasswordView: Верификация через AuthManager не удалась")
                // AuthManager сам установит сообщение об ошибке, которое отобразится в UI
            }
        }
    }
    
    // In ResetPasswordView.swift

    private func setNewPassword() {
        // Валидация пароля остается прежней
        let passwordValidation = PasswordValidator.validate(newPassword)
        if !passwordValidation.isValid {
            authManager.appError = AppError(message: passwordValidation.errorMessage ?? "Password validation failed.")
            return
        }

        // Теперь мы вызываем упрощенный метод AuthManager
        Task {
            await authManager.confirmPasswordReset(newPassword: newPassword)
        }
    }
    
    private func resendCode() {
        // Clear any existing errors
        authManager.appError = nil
        
        Task {
            await authManager.requestPasswordReset(email: email)
            
            // Show success message if code was sent
            if authManager.appError == nil {
                authManager.appError = AppError(message: "Verification code sent to \(email)", isSuccess: true)
                // Reset verification state when new code is sent
                isCodeVerified = false
                verifiedCode = nil // Clear stored verified code
                // Clear the previous verification code
                verificationCode = ""
                // Reset focus to allow new input
                isCodeFieldFocused = true
            }
        }
        
        // Reset timer
        canResend = false
        resendCountdown = 60
        startResendTimer()
    }
    
    private func startResendTimer() {
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                canResend = true
                resendTimer?.invalidate()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
