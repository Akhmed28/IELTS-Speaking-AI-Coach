import SwiftUI
import Foundation

public struct PasswordRequirementsView: View {
    public var password: String
    public var confirmPassword: String? = nil
    
    public init(password: String, confirmPassword: String? = nil) {
        self.password = password
        self.confirmPassword = confirmPassword
    }
    
    // Computed properties to cache validation results and prevent recalculation
    private var requirements: (lengthValid: Bool, specialCharValid: Bool) {
        PasswordValidator.checkRequirements(password)
    }
    
    private var passwordsMatch: Bool {
        guard let confirm = confirmPassword, !password.isEmpty else { return false }
        return password == confirm
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Length requirement
            RequirementRow(
                isValid: requirements.lengthValid,
                text: "At least \(PasswordValidator.minimumLength) characters"
            )
            
            // Special character requirement
            RequirementRow(
                isValid: requirements.specialCharValid,
                text: "Must include special character (-, _, !, @, #, $, %, etc.)"
            )
            
            // Password match requirement (only if confirmPassword is provided)
            if confirmPassword != nil {
                RequirementRow(
                    isValid: passwordsMatch,
                    text: "Passwords match"
                )
            }
        }
        .padding(.vertical, 4)
        .animation(.none) // Disable all animations to prevent lag
    }
}

// Separate view for each requirement row to optimize rendering
private struct RequirementRow: View {
    let isValid: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isValid ? .green : .red)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .animation(.none) // Disable animations for individual rows
    }
}
