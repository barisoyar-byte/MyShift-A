import SwiftUI

struct MenuView: View {
    var body: some View {
        VStack(alignment: .center) {
            NavigationLink(destination: EkipView()) {
                Text("Ekip")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: PlanlamaView()) {
                Text("Planlama")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: TakvimView()) {
                Text("Takvim")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: ArşivView()) {
                Text("Arşiv")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: FormlarView()) {
                Text("Formlar")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: PlanlamaView()) {
                Text("Planlama")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: GeçiciGörevlerView()){
                    Text("Geçici Görevler")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: PlanlamaView()) {
                Text("Koşullar")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink(destination: PlanlamaView()) {
                Text("Planlama")
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
            }
            
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
