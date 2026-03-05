//
//  ContentView.swift
//  MyShift A
//
//  Created by Barış Oyar on 21.02.2026.
//

import SwiftUI
import SwiftData
struct GestureView: View {
    var body: some View {
        Text("Tapped!")
            .font(.title)
            .foregroundStyle(.primary)
            .padding()
    }
}
struct ContentView: View {
    @AppStorage("Menu") private var menu = false
    @State private var navigateToMenu = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .center) {
                Image("arka plan")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(20)
                    .onTapGesture {
                        navigateToMenu = true
                    }

                Text("Devam etmek için tıklayın")
                    .foregroundStyle(.blue)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .onTapGesture {
                        navigateToMenu = true
                    }
            }
            .padding()
            .navigationDestination(isPresented: $navigateToMenu) {
                MenuView()
            }
            .onChange(of: navigateToMenu) { _, newValue in
                // no-op: the destination is driven by the binding
            }
        }
    }
}

#Preview {
    ContentView()
}
