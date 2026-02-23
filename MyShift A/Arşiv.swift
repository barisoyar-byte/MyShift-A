//
//  Arşiv.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI
struct ArşivGestureView: View {
    var body: some View {
        Text("Tapped!")
            .font(.title)
            .foregroundStyle(.primary)
            .padding()
    }
}
struct ArşivView: View {
    @AppStorage("Menu") private var menu = false
    @State private var navigateToMenu = false

    var body: some View {
        VStack {
            Text("Gündüz")
                .font(.largeTitle.bold())
                .padding()
        }
        .navigationTitle("Arşiv")
        .navigationBarTitleDisplayMode(.inline)
    }
}
