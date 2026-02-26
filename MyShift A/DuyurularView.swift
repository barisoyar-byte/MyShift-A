import SwiftUI

struct DuyurularView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Yakında")
                .font(.largeTitle.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("Duyurular")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { DuyurularView() }
}
