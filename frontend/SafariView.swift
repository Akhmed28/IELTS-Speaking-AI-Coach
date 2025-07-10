import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        // Creates the Safari view controller with the specified URL.
        // This uses Apple's recommended in-app browser.
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // This function is required by the protocol, but we don't need to update
        // the view controller after it has been created.
    }
}
