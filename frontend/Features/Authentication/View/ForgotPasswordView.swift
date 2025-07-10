import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var errorFlash = false
    @State private var showContent = false

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
                                // Forgot password icon with animation
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 50, weight: .light))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(showContent ? 1.0 : 0.5)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showContent)
                                
                                VStack(spacing: 12) {
                                    Text("Forgot Password?")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Enter your email address and we'll send you a verification code to reset your password.")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                                .opacity(showContent ? 1.0 : 0.0)
                                .animation(.easeInOut(duration: 0.8).delay(0.3), value: showContent)
                            }
                            
                            // Form section
                            VStack(spacing: 24) {
                                // Error message
                if let error = authManager.appError {
                                    VStack(spacing: 12) {
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
                                        
                                        // Show "Create Account" button if account doesn't exist
                                        if error.message.lowercased().contains("does not exist") {
                                            Button("Create New Account") {
                                                dismiss()
                                                // Navigate to registration
                                            }
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(Color.green.opacity(0.8))
                                            )
                                        }
                                    }
                                    .scaleEffect(errorFlash ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: errorFlash)
                        .onChange(of: error.message) { _ in
                                        withAnimation {
                                            errorFlash.toggle()
                                        }
                                    }
                                }
                                
                                // Email input section
                                VStack(spacing: 16) {
                                    Text("Enter your email")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    // Email input field
                                    HStack {
                                        Image(systemName: "envelope")
                                            .foregroundColor(.gray)
                                            .frame(width: 20)
                                        
                                        NoSelectTextFieldStyle(
                                            text: $email,
                                            placeholder: "Email Address",
                                            keyboardType: .emailAddress,
                                            autocapitalizationType: .none
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.9))
                                    )
                                    .onChange(of: email) { newValue in
                                        // Limit email to 50 characters
                                        if newValue.count > 50 {
                                            email = String(newValue.prefix(50))
                                        }
                                    }
                                }
                                
                                // Send reset code button
                                Button(action: sendResetCode) {
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "paperplane.fill")
                                                .font(.title3)
                                        }
                                        
                                        Text(authManager.isLoading ? "Sending..." : "Send Reset Code")
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
                                .disabled(authManager.isLoading || email.isEmpty)
                                .opacity(email.isEmpty ? 0.6 : 1.0)
                                .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: authManager.isLoading)
                            }
                            .padding(.horizontal, 32)
                            
                            Spacer()
                            
                            // Back button
                            Button("← Cancel") {
                                dismiss()
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
        }
        .onTapGesture {
            hideKeyboard()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func sendResetCode() {
                    // Input validation
                    if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        authManager.appError = AppError(message: "Email field cannot be empty.")
                        triggerErrorFlash()
                        return
                    }
                    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
                    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
                    if !emailPredicate.evaluate(with: email) {
                        authManager.appError = AppError(message: "Please enter a valid email.")
                        triggerErrorFlash()
                        return
                    }
                    Task {
                        await authManager.requestPasswordReset(email: email)
        }
    }

    // Helper to trigger error animation
    private func triggerErrorFlash() {
        errorFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.2)) {
                errorFlash = false
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
