// In the ChatView.swift file
import SwiftUI
//import Networking

// Helper structure for Share Sheet remains unchanged
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


struct ChatView: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    @State private var prompt: String = ""
    
    @State private var showingShareSheet = false
    @State private var reportURL: URL?

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.chatMessages) { message in
                        HStack {
                            // --- CORRECTION ---
                            // Replace isFromUser with role check
                            if message.role == .user { Spacer() }
                            
                            // Replace message.text with message.content
                            Text(message.content)
                                .padding(10)
                                .background(message.role == .user ? Color.blue : Color(UIColor.systemGray5))
                                .foregroundColor(message.role == .user ? .white : .primary)
                                .cornerRadius(15)
                                
                            if message.role != .user { Spacer() }
                        }
                    }
                }
                .padding()
            }

            HStack {
                TextField("Ask anything...", text: $prompt)
                    .autocorrectionDisabled()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // ChatView.swift
                Button("Send") {
                    let messageToSend = prompt
                    prompt = ""
                    Task { await viewModel.sendMessage(messageToSend) }   // ✅ uncommented
                }
                .disabled(prompt.isEmpty)

            }
            .padding()
        }
        .navigationTitle("AI Assistant")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Download Report") {
                    Task {
                        if let url = await viewModel.downloadReport() {
                            self.reportURL = url
                            self.showingShareSheet = true
                        }
                    }
                }
                .disabled(viewModel.chatMessages.isEmpty)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = reportURL {
                ShareSheet(items: [url])
            }
        }
    }
}
