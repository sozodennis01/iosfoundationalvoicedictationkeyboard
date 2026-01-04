import SwiftUI
import Speech
import AVFoundation

@available(iOS 26.0, *)
struct SettingsView: View {
    @State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @State private var speechRecognitionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationView {
            List {
                // Permissions Section
                Section {
                    PermissionRow(
                        title: "Microphone",
                        status: microphonePermissionText,
                        statusColor: microphonePermissionColor,
                        action: requestMicrophonePermission
                    )

                    PermissionRow(
                        title: "Speech Recognition",
                        status: speechRecognitionPermissionText,
                        statusColor: speechRecognitionPermissionColor,
                        action: requestSpeechRecognitionPermission
                    )
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Both microphone and speech recognition permissions are required for voice dictation to work.")
                }

                // Keyboard Setup Instructions
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionStep(number: 1, text: "Go to Settings → General → Keyboard")
                        InstructionStep(number: 2, text: "Tap 'Keyboards' → 'Add New Keyboard'")
                        InstructionStep(number: 3, text: "Select 'VoiceDictation'")
                        InstructionStep(number: 4, text: "Enable 'Allow Full Access'")
                    }
                    .padding(.vertical, 8)

                    Button("Open Keyboard Settings") {
                        openKeyboardSettings()
                    }
                } header: {
                    Text("Keyboard Setup")
                } footer: {
                    Text("Full Access is required for the keyboard to communicate with the host app via App Groups.")
                }

                // App Information
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("iOS Requirement")
                        Spacer()
                        Text("iOS 26+")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            updatePermissionStatuses()
        }
    }

    // MARK: - Permission Status Text

    private var microphonePermissionText: String {
        switch microphoneStatus {
        case .authorized:
            return "Authorized"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }

    private var speechRecognitionPermissionText: String {
        switch speechRecognitionStatus {
        case .authorized:
            return "Authorized"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Unknown"
        }
    }

    private var microphonePermissionColor: Color {
        microphoneStatus == .authorized ? .green : .red
    }

    private var speechRecognitionPermissionColor: Color {
        speechRecognitionStatus == .authorized ? .green : .red
    }

    // MARK: - Actions

    private func updatePermissionStatuses() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechRecognitionStatus = SFSpeechRecognizer.authorizationStatus()
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                updatePermissionStatuses()
            }
        }
    }

    private func requestSpeechRecognitionPermission() {
        Task {
            let status = await SFSpeechRecognizer.requestAuthorization()
            await MainActor.run {
                speechRecognitionStatus = status
            }
        }
    }

    private func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct PermissionRow: View {
    let title: String
    let status: String
    let statusColor: Color
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if status != "Authorized" {
                Button("Request") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@available(iOS 26.0, *)
#Preview {
    SettingsView()
}
