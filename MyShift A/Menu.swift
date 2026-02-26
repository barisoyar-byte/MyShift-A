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
            
            NavigationLink(destination: ArşivGestureView()) {
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
            NavigationLink(destination: İstatistiklerView()) {
                Text("İstatistikler")
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
            
            NavigationLink(destination: KoşullarView()) {
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
            
            NavigationLink(destination: DuyurularView()) {
                Text("Duyurular")
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
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MenuView()
    }
}

