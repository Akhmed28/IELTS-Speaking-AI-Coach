// VerificationView.swift
import SwiftUI

public struct VerificationView: View {
    @EnvironmentObject var authManager: AuthManager
    public let email: String
    
    @State private var verificationCode = ""
    @State private var showContent = false
    @State private var errorFlash = false
    @State private var canResend = false
    @State private var resendCountdown = 60
    @State private var resendTimer: Timer?
    @State private var showCursor = true
    @FocusState private var isCodeFieldFocused: Bool
    
    private let codeLength = 6
    
    public init(email: String) {
        self.email = email
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                        Spacer()
                            .frame(height: geometry.size.height * 0.15)
                        
                        VStack(spacing: 32) {
                            VStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "envelope.badge.fill")
                                        .font(.system(size: 50, weight: .light))
                                        .foregroundColor(.white)
                                }
                                .scaleEffect(showContent ? 1.0 : 0.5)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showContent)
                                
                                VStack(spacing: 12) {
                                    Text("Verify Your Email")
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
                            
                            VStack(spacing: 24) {
                                if let appError = authManager.appError {
                                    HStack {
                                        Image(systemName: appError.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(appError.isSuccess ? .green : .red)
                                        Text(appError.message)
                                            .font(.caption)
                                            .foregroundColor(appError.isSuccess ? .green : .red)
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
                                    .onChange(of: appError.message) { _ in
                                        withAnimation {
                                            errorFlash.toggle()
                                        }
                                    }
                                }
                                
                                VStack(spacing: 16) {
                                    Text("Enter verification code")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
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
                                                
                                                if verificationCode.count > index {
                                                    Text(getDigit(at: index))
                                                        .font(.title)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.black)
                                                } else if verificationCode.count == index && isCodeFieldFocused {
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
                                        TextField("", text: $verificationCode)
                                            .keyboardType(.numberPad)
                                            .textContentType(.oneTimeCode)
                                            .foregroundColor(.clear)
                                            .accentColor(.clear)
                                            .background(Color.clear)
                                            .focused($isCodeFieldFocused)
                                            .onChange(of: verificationCode) { newValue in
                                                let filtered = newValue.filter { $0.isNumber }
                                                if filtered.count > codeLength {
                                                    verificationCode = String(filtered.prefix(codeLength))
                                                } else {
                                                    verificationCode = filtered
                                                }
                                                
                                                if verificationCode.count == codeLength {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                        verifyCode()
                                                    }
                                                }
                                            }
                                            .opacity(0.01)
                                    )
                                    
                                    Text(isCodeFieldFocused ? "Enter the 6-digit code" : "Tap above to enter code")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .animation(.easeInOut(duration: 0.3), value: isCodeFieldFocused)
                                }
                                
                                Button(action: verifyCode) {
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                        }
                                        
                                        Text("Verify & Complete Registration")
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
                                
                                VStack(spacing: 12) {
                                    if canResend {
                                        Button("Resend verification code") {
                                            resendVerificationCode()
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
                            .padding(.horizontal, 32)
                            
                            Spacer()
                            
                            Button("← Go Back") {
                                authManager.cancelVerification()
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isCodeFieldFocused = true
            }
            
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                showCursor = true
            }
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
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
    
    private func verifyCode() {
        guard verificationCode.count == codeLength else {
            authManager.appError = AppError(message: "Please enter the complete 6-digit code.")
            return
        }
        
        Task {
            await authManager.verifyAccount(code: verificationCode)
        }
    }
    
    private func resendVerificationCode() {
        Task {
            await authManager.resendVerificationCode()
        }
        
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
