import SwiftUI
import UIKit

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // State to toggle between Login and Sign Up forms
    @State private var isLoginMode = true
    
    // Animation states
    @State private var showContent = false
    @State private var currentOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background with beautiful gradients
                if isLoginMode {
                    // Login page - Professional blue gradient
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.cyan.opacity(0.6),
                            Color.blue.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                } else {
                    // Registration page - Pure purple gradient
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
                }
                
                // Animated background particles
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 40...120))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 2)
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.5),
                            value: showContent
                        )
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Top spacing
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)
                        
                        // Main content container
                        VStack(spacing: 30) {
                            // App logo and branding
                            VStack(spacing: 16) {
                                // App icon
                                Image(systemName: isLoginMode ? "brain.head.profile" : "sparkles")
                                    .font(.system(size: 60, weight: .light))
                                    .foregroundColor(.white)
                                    .scaleEffect(showContent ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showContent)
                                
                                // App name
                                Text("IELTS Practice AI")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .opacity(showContent ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: showContent)
                            }
                            .padding(.bottom, 20)
                            
                            // Authentication forms
                            if isLoginMode {
                                LoginFormView()
                                    .environmentObject(authManager)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                            } else {
                                RegistrationFormView()
                                    .environmentObject(authManager)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                            
                            // Mode toggle button
                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    authManager.appError = nil
                                    isLoginMode.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                    Text(isLoginMode ? "New here? Create an account" : "Already have an account? Sign in")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .scaleEffect(showContent ? 1.0 : 0.8)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.8), value: showContent)
                        }
                        .padding(.horizontal, 32)
                        .offset(y: currentOffset)
                        
                        // Add bottom padding to ensure content is visible above keyboard
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
        .sheet(isPresented: $authManager.showingForgotPasswordSheet) {
            ForgotPasswordView()
                .environmentObject(authManager)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            // Set text field appearance
            UITextField.appearance().tintColor = UIColor.black
        }
    }
}

// MARK: - Login Form View
struct LoginFormView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var errorFlash = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Page title
            Text("Login")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Form container
            VStack(spacing: 20) {
                // Error message
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
                
                // Email field
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    CustomTextField(text: $email, placeholder: "Email", keyboardType: .emailAddress)
                        .frame(maxWidth: .infinity)
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
                
                // Password field
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    if isPasswordVisible {
                        CustomTextField(text: $password, placeholder: "Password")
                            .frame(maxWidth: .infinity)
                    } else {
                        CustomSecureField(text: $password, placeholder: "Password")
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
                
                // Forgot password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        authManager.appError = nil
                        authManager.showingForgotPasswordSheet = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                }
                
                // Sign in button
                Button(action: signIn) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        
                        Text("Sign In")
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
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(authManager.isLoading)
                .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: authManager.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .onChange(of: email) { newValue in
                // Limit email to 50 characters
                if newValue.count > 50 {
                    email = String(newValue.prefix(50))
                }
            }
            .onChange(of: password) { newValue in
                // Limit password to 30 characters
                if newValue.count > 30 {
                    password = String(newValue.prefix(30))
                }
            }
        }
    }
    
    private func signIn() {
        // Input validation
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Email field cannot be empty.")
            return
        }
        if password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Password field cannot be empty.")
            return
        }
        
        Task {
            await authManager.login(email: email, password: password)
        }
    }
}

// MARK: - Registration Form View
struct RegistrationFormView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var agreeToTerms = false
    @State private var errorFlash = false
    
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Page title
            Text("Register")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Form container
            VStack(spacing: 20) {
                // Error message (only show errors, not success messages)
                if let appError = authManager.appError, !appError.isSuccess {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(appError.message)
                            .font(.caption)
                            .foregroundColor(.red)
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
                
                // Show warning if user hit the limit
                if fullName.count >= 20 {
                    Text("You hit the maximum character limit")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.bottom, 2)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: fullName.count)
                }
                // Full name field
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    CustomTextField(text: $fullName, placeholder: "Full Name")
                        .frame(maxWidth: .infinity)
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
                .onChange(of: fullName) { newValue in
                    // Limit name to 20 characters
                    if newValue.count > 20 {
                        fullName = String(newValue.prefix(20))
                    }
                }

                // Email field
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    CustomTextField(text: $email, placeholder: "Email", keyboardType: .emailAddress)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                )
                .contentShape(Rectangle())
                .onTapGesture { }
                .onChange(of: email) { newValue in
                    if newValue.count > 50 {
                        email = String(newValue.prefix(50))
                    }
                }

                // Password field
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    if isPasswordVisible {
                        CustomTextField(text: $password, placeholder: "Password")
                            .frame(maxWidth: .infinity)
                    } else {
                        CustomSecureField(text: $password, placeholder: "Password")
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
                .onTapGesture { }
                .onChange(of: password) { newValue in
                    if newValue.count > 30 {
                        password = String(newValue.prefix(30))
                    }
                }

                // Confirm password field
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                    
                    if isConfirmPasswordVisible {
                        CustomTextField(text: $confirmPassword, placeholder: "Confirm Password")
                            .frame(maxWidth: .infinity)
                    } else {
                        CustomSecureField(text: $confirmPassword, placeholder: "Confirm Password")
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: { isConfirmPasswordVisible.toggle() }) {
                        Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
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
                .onTapGesture { }
                .onChange(of: confirmPassword) { newValue in
                    if newValue.count > 30 {
                        confirmPassword = String(newValue.prefix(30))
                    }
                }
                
                // Password requirements
                if !password.isEmpty {
                    PasswordRequirementsView(password: password, confirmPassword: confirmPassword)
                        .animation(.none, value: password)
                }
                
                // Privacy Policy Agreement
                HStack(alignment: .top, spacing: 12) {
                    Button(action: { agreeToTerms.toggle() }) {
                        Image(systemName: agreeToTerms ? "checkmark.square.fill" : "square")
                            .foregroundColor(agreeToTerms ? .green : .white.opacity(0.7))
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("I agree to the")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Button(action: {
                                showingPrivacyPolicy = true
                            }) {
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .underline()
                            }
                        }
                    }
                    Spacer()
                }
                
                // Sign up button
                Button(action: signUp) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.title3)
                        }
                        
                        Text("Create Account")
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
                .disabled(authManager.isLoading || !agreeToTerms)
                .opacity(agreeToTerms ? 1.0 : 0.6)
                .scaleEffect(authManager.isLoading ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: authManager.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .sheet(isPresented: $showingPrivacyPolicy) {
                SafariView(url: URL(string: "https://www.privacypolicies.com/live/d7662810-bda4-4d31-be92-d52b1413c841")!)
            }
        }
    }
    
    private func signUp() {
        // Input validation
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Full name field cannot be empty.")
            return
        }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Email field cannot be empty.")
            return
        }
        if confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            authManager.appError = AppError(message: "Please confirm your password.")
            return
        }
        
        let passwordValidation = PasswordValidator.validatePasswordMatch(password, confirmPassword: confirmPassword)
        if !passwordValidation.isValid {
            authManager.appError = AppError(message: passwordValidation.errorMessage ?? "Password validation failed.")
            return
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            authManager.appError = AppError(message: "Please enter a valid email address.")
            return
        }
        
        if !agreeToTerms {
            authManager.appError = AppError(message: "Please agree to the Privacy Policy.")
            return
        }
        
        Task {
            await authManager.register(email: email, password: password, name: fullName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

// MARK: - Keyboard Adaptive Modifier
extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        keyboardHeight = keyboardFrame.cgRectValue.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = 0
                }
            }
    }
}

// MARK: - Custom Text Field Without Toolbar
struct NoToolbarTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var autocorrectionType: UITextAutocorrectionType = .no
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        textField.inputAccessoryView = UIView()
        textField.delegate = context.coordinator
        textField.tintColor = UIColor.black
        textField.text = text
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: NoToolbarTextField
        
        init(_ parent: NoToolbarTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            textField.removeTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }
    }
}



// MARK: - Helper Functions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Custom Secure Text Field
struct CustomSecureField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeUIView(context: Context) -> UITextField {
        let textField = NoSelectUITextField()
        textField.placeholder = placeholder
        textField.isSecureTextEntry = true
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.delegate = context.coordinator
        textField.tintColor = UIColor.black
        textField.textColor = UIColor.black
        
        // --- FIX: Add this line to enable horizontal scrolling ---
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: CustomSecureField
        
        init(_ parent: CustomSecureField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .none
    
    func makeUIView(context: Context) -> UITextField {
        let textField = NoSelectUITextField()
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no
        textField.delegate = context.coordinator
        textField.tintColor = UIColor.black
        textField.textColor = UIColor.black
        
        // --- FIX: Add this line to enable horizontal scrolling ---
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

// A preview provider to see the view in Xcode's canvas
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(AuthManager())
    }
}
