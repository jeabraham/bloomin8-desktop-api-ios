import Bloomin8Core
import SwiftUI

struct ContentView: View {
    @AppStorage("frameHost") private var savedHost = ""
    @State private var hostDraft = ""
    @State private var galleries: [Gallery] = []
    @State private var selectedGallery: String?
    @State private var intervalSeconds = "120"
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var isLoading = false

    private let api = Bloomin8APIClient()

    var body: some View {
        NavigationStack {
            Form {
                Section("Frame") {
                    TextField("Hostname or IP address", text: $hostDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Save & Connect") {
                        connect()
                    }
                    .disabled(isLoading)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(statusIsError ? .red : .secondary)
                            .accessibilityIdentifier("connectionStatus")
                    }
                }

                Section("Slideshow") {
                    if galleries.isEmpty {
                        Text("Connect to load galleries.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Gallery", selection: $selectedGallery) {
                            ForEach(galleries) { gallery in
                                Text(gallery.name).tag(gallery.name as String?)
                            }
                        }
                    }

                    TextField("Interval in seconds", text: $intervalSeconds)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("intervalSeconds")
                    Text("The frame API uses seconds; 7,200 seconds is two hours.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Start Slideshow") {
                        startSlideshow()
                    }
                    .disabled(isLoading || selectedGallery == nil || savedHost.isEmpty)
                }
            }
            .navigationTitle("Bloomin8 Frame")
            .onAppear {
                hostDraft = savedHost
            }
        }
    }

    private func connect() {
        let host = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try Bloomin8APIClient.baseURL(for: host)
        } catch {
            show(error)
            return
        }

        savedHost = host
        galleries = []
        selectedGallery = nil
        isLoading = true
        statusIsError = false
        statusMessage = "Connecting to \(host)…"

        Task {
            defer { isLoading = false }
            do {
                let loadedGalleries = try await api.galleries(host: host)
                galleries = loadedGalleries
                if !loadedGalleries.contains(where: { $0.name == selectedGallery }) {
                    selectedGallery = loadedGalleries.first?.name
                }
                statusMessage = loadedGalleries.isEmpty
                    ? "Connected. No galleries were found."
                    : "Connected. \(loadedGalleries.count) galleries available."
            } catch {
                show(error)
            }
        }
    }

    private func startSlideshow() {
        guard let gallery = selectedGallery else { return }
        guard let seconds = Int(intervalSeconds), seconds > 0 else {
            show(Bloomin8APIError.invalidDuration)
            return
        }

        isLoading = true
        statusIsError = false
        statusMessage = "Starting slideshow…"

        Task {
            defer { isLoading = false }
            do {
                try await api.startSlideshow(
                    host: savedHost,
                    gallery: gallery,
                    durationSeconds: seconds
                )
                statusMessage = "Slideshow started for \(gallery)."
            } catch {
                show(error)
            }
        }
    }

    private func show(_ error: Error) {
        statusIsError = true
        statusMessage = error.localizedDescription
    }
}
