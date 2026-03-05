import SwiftUI
import SwiftData

struct KoşullarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Yakında")
                .font(.largeTitle.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}
#Preview {
    NavigationStack { KoşullarView() }
}
