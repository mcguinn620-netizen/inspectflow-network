import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Name", value: AINBrand.displayName)
                LabeledContent("Version", value: appVersion)
            }
            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://autoinspector.network/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://autoinspector.network/terms")!)
            }
        }
        .navigationTitle("About")
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
