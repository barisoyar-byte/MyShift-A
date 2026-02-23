//
//  Untitled.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI
struct EkipGestureView: View {
    var body: some View {
        Text("Tapped!")
            .font(.title)
            .foregroundStyle(.primary)
            .padding()
    }
}
struct EkipView: View {
    @AppStorage("Menu") private var menu = false
    @State private var navigateToMenu = false

    var body: some View {
        VStack {
            Text("Initial")
                .font(.largeTitle.bold())
                .padding()
        }
        .navigationTitle("Ekip")
        .navigationBarTitleDisplayMode(.inline)
    }
}

