import SwiftUI

struct BridgeSettings: View {
    @AppStorage("bridgeURL") private var savedURL = PlacesClient.defaultURL
    @State private var url = ""
    @State private var token = ""
    @State private var status: String?
    @State private var testing = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Search bridge") {
                    TextField("http://127.0.0.1:8787", text: $url)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    SecureField("Access token (for iPhone / LAN)", text: $token)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
                Section {
                    Text("Run Bridge/run.sh on your Mac. Simulator and Mac use 127.0.0.1. On iPhone, enter your Mac’s local IP address or .local hostname, with port 8787.")
                    Text("Search uses the visible map area. Your Google API key stays in your scripts environment on the Mac. The access token is saved in Keychain.")
                }
                .font(.footnote).foregroundStyle(.secondary)
                Section {
                    Button {
                        testing = true
                        status = nil
                        Task {
                            do {
                                try await PlacesClient(baseURL: url, token: token).health()
                                status = "Connected to your search bridge."
                            } catch { status = error.localizedDescription }
                            testing = false
                        }
                    } label: {
                        HStack { Text("Test connection"); if testing { Spacer(); ProgressView() } }
                    }
                    .disabled(testing)
                    if let status { Text(status).font(.footnote) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Search Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let endpoint = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
                              ["http", "https"].contains(endpoint.scheme?.lowercased() ?? ""), endpoint.host != nil,
                              endpoint.user == nil, endpoint.password == nil, endpoint.query == nil, endpoint.fragment == nil else {
                            status = "Enter an HTTP or HTTPS URL without a query, fragment, or embedded credentials."
                            return
                        }
                        do {
                            try BridgeCredential.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
                            savedURL = endpoint.absoluteString
                            dismiss()
                        } catch { status = error.localizedDescription }
                    }
                }
            }
        }
        .frame(minWidth: 340, minHeight: 400)
        .onAppear { url = savedURL; token = BridgeCredential.read() }
    }
}
