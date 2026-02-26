import Foundation

// Shared entry model used by Planlama and Arsiv screens
struct PlanlamaEntry: Identifiable, Equatable {
    let id = UUID()
    var mloExe: String
    var mloPln: String
    var ojtil: String
    var muwExe: String
    var muwPln: String
    var ojtiu: String
}

#if canImport(UIKit)
import SwiftUI
import UIKit

private struct ForceLandscapeController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            let value = UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }
        override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
        override var shouldAutorotate: Bool { true }
    }
}

private struct ForceLandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ForceLandscapeController().ignoresSafeArea())
    }
}

extension View {
    func forceLandscapeIfPossible() -> some View { self.modifier(ForceLandscapeModifier()) }
}
#endif

import SwiftUI

struct TakvimWrapperView: View {
    var body: some View {
        #if canImport(UIKit)
        TakvimGestureView()
            .forceLandscapeIfPossible()
        #else
        TakvimGestureView()
        #endif
    }
}
