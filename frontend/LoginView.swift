// LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    @State private var username = ""
    @State private var password = ""
    private enum FocusableField: Hashable { case username, password }
    @FocusState private var focusedField: FocusableField?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome Back!")
                .font(.largeTitle).fontWeight(.bold)
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle()).autocapitalization(.none)
                .focused($focusedField, equals: .username)
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .password)
                .onTapGesture { focusedField = .password }
            if let error = viewModel.loginError {
                Text(error).foregroundColor(.red).font(.caption)
            }
            Button("Login") {
                Task { await viewModel.login(username: username, password: password) }
            }
            .padding().frame(maxWidth: .infinity).background(Color.blue).foregroundColor(.white).cornerRadius(10)
        }.padding()
    }
}
