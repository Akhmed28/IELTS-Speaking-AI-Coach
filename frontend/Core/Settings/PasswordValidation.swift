import Foundation

// MARK: - Password Validation Utility
struct PasswordValidator {
    static let minimumLength = 6
    static let requiredSpecialCharacters = Set(["-", "_", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "+", "=", "[", "]", "{", "}", "|", "\\", ":", ";", "\"", "'", "<", ">", ",", ".", "?", "/", "~", "`"])
    
    static func validate(_ password: String) -> (isValid: Bool, errorMessage: String?) {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if password is empty
        if trimmedPassword.isEmpty {
            return (false, "Password field cannot be empty.")
        }
        
        // Check minimum length
        if trimmedPassword.count < minimumLength {
            return (false, "Password must be at least \(minimumLength) characters long.")
        }
        
        // Check for special characters
        let passwordCharacters = Set(trimmedPassword.map { String($0) })
        let hasSpecialCharacter = !passwordCharacters.isDisjoint(with: requiredSpecialCharacters)
        
        if !hasSpecialCharacter {
            return (false, "Password must contain at least one special character (-, _, !, @, #, $, %, etc.).")
        }
        
        return (true, nil)
    }
    
    static func validatePasswordMatch(_ password: String, confirmPassword: String) -> (isValid: Bool, errorMessage: String?) {
        // First validate the password itself
        let passwordValidation = validate(password)
        if !passwordValidation.isValid {
            return passwordValidation
        }
        
        // Check if passwords match
        if password != confirmPassword {
            return (false, "Passwords do not match.")
        }
        
        return (true, nil)
    }
    
    static func getRequirementsText() -> String {
        return "• At least \(minimumLength) characters\n• Must include special characters (-, _, !, @, #, $, %, etc.)"
    }
    
    static func checkRequirements(_ password: String) -> (lengthValid: Bool, specialCharValid: Bool) {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let lengthValid = trimmedPassword.count >= minimumLength
        
        let passwordCharacters = Set(trimmedPassword.map { String($0) })
        let specialCharValid = !passwordCharacters.isDisjoint(with: requiredSpecialCharacters)
        
        return (lengthValid, specialCharValid)
    }
}

// MARK: - AppError Extension
extension AppError {
    static func passwordValidationError(_ message: String) -> AppError {
        return AppError(message: message)
    }
}
