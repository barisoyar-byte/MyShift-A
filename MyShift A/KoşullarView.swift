import SwiftUI

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
        .navigationTitle("Koşullar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { KoşullarView() }
}
