import SwiftUI

struct MenuView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Menu")
                .font(.largeTitle.bold())
            Text("Burada menü içeriği olacak.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Menü")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MenuView()
    }
}
