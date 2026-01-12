import SwiftUI

struct MicButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.blue)
                .clipShape(Circle())
        }
    }
}

#Preview {
    MicButton(action: {})
        .padding()
        .background(Color.gray)
}
