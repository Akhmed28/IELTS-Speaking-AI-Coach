import SwiftUI
import UIKit

// MARK: - Custom TextField that allows precise cursor placement

struct NoSelectTextFieldStyle: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var autocapitalizationType: UITextAutocapitalizationType = .none

    func makeUIView(context: Context) -> NoSelectUITextField {
        let textField = NoSelectUITextField()
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isSecure
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .no
        textField.delegate = context.coordinator
        textField.tintColor = UIColor.label
        textField.textColor = UIColor.label
        
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no

        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange), for: .editingChanged)
        return textField
    }

    // ## THIS IS THE KEY FIX ##
    // This function is now updated to preserve the cursor position.
    func updateUIView(_ uiView: NoSelectUITextField, context: Context) {
        // Only update if the text from the state differs from the text field's content.
        if uiView.text != text {
            // 1. Store the current cursor position/selection.
            let oldSelectedRange = uiView.selectedTextRange

            // 2. Update the text. This is what was causing the cursor to jump.
            uiView.text = text

            // 3. Restore the cursor position. This overrides the jump and places
            //    the cursor exactly where it was.
            uiView.selectedTextRange = oldSelectedRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: NoSelectTextFieldStyle

        init(_ parent: NoSelectTextFieldStyle) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}

// MARK: - Custom UITextField Subclass (No changes here from last time)

class NoSelectUITextField: UITextField {

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        self.spellCheckingType = .no
        self.autocorrectionType = .no
    }
    
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if success, let text = self.text {
            let newPosition = self.textRange(from: self.endOfDocument, to: self.endOfDocument)
            self.selectedTextRange = newPosition
        }
        return success
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return super.canPerformAction(action, withSender: sender)
        }

        if [#selector(UIResponderStandardEditActions.select(_:)),
            #selector(UIResponderStandardEditActions.selectAll(_:)),
            #selector(UIResponderStandardEditActions.copy(_:)),
            #selector(UIResponderStandardEditActions.cut(_:))].contains(action) {
            return false
        }

        return super.canPerformAction(action, withSender: sender)
    }
}


// MARK: - SwiftUI View Extension (No changes needed here)

extension View {
    func noSelectTextField(text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default, isSecure: Bool = false, autocapitalizationType: UITextAutocapitalizationType = .none) -> some View {
        NoSelectTextFieldStyle(
            text: text,
            placeholder: placeholder,
            keyboardType: keyboardType,
            isSecure: isSecure,
            autocapitalizationType: autocapitalizationType
        )
    }
}
