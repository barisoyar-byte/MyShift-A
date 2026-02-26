//
//  Gündüz Formlar.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI
struct FormlarGestureView: View {
    var body: some View {
        Text("Tapped!")
            .font(.title)
            .foregroundStyle(.primary)
            .padding()
    }
}
struct FormlarView: View {
    @AppStorage("Menu") private var menu = false
    @State private var navigateToMenu = false

    var body: some View {
        VStack {
            Text("Initial")
                .font(.largeTitle.bold())
                .padding()
        }

        .navigationBarTitleDisplayMode(.inline)
    }
}
