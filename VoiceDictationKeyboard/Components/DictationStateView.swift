import SwiftUI

struct DictationStateView: View {
    enum State {
        case idle
        case arming
        case listening
        case processing
        case error(String)
    }

    let state: State
    let onStop: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                switch state {
                case .idle:
                    EmptyView()

                case .arming:
                    ProgressView()
                    Text("Opening app...")
                        .foregroundColor(.white)

                case .listening:
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    Text("Listening...")
                        .foregroundColor(.white)
                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.borderedProminent)

                case .processing:
                    ProgressView()
                    Text("Processing...")
                        .foregroundColor(.white)

                case .error(let message):
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    Text(message)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    DictationStateView(state: .listening, onStop: {})
}
