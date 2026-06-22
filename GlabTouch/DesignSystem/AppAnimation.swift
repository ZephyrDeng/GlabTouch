import SwiftUI

enum AppAnimation {
    /// Expo-out curve for stage disclosure expand/collapse (220ms)
    static let stageDisclosure = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.22)

    /// Content reveal transition: opacity + slide from top
    static func contentReveal(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .move(edge: .top))
    }

    /// Conditionally wraps a closure in animation, respecting reduceMotion
    static func withMotion(reduceMotion: Bool, _ body: () -> Void) {
        withAnimation(reduceMotion ? nil : stageDisclosure, body)
    }
}
