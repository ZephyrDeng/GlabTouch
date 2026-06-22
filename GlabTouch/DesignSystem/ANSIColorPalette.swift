import SwiftUI

enum ANSIColorPalette {
    struct Palette {
        let colors: [Color]
    }

    static let light = Palette(colors: [
        Color(red: 0, green: 0, blue: 0),
        Color(red: 0.8, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.6, blue: 0.0),
        Color(red: 0.6, green: 0.5, blue: 0.0),
        Color(red: 0.0, green: 0.0, blue: 0.8),
        Color(red: 0.6, green: 0.0, blue: 0.6),
        Color(red: 0.0, green: 0.6, blue: 0.6),
        Color(red: 0.8, green: 0.8, blue: 0.8),
        Color(red: 0.5, green: 0.5, blue: 0.5),
        Color(red: 1.0, green: 0.0, blue: 0.0),
        Color(red: 0.0, green: 0.8, blue: 0.0),
        Color(red: 0.8, green: 0.8, blue: 0.0),
        Color(red: 0.2, green: 0.2, blue: 1.0),
        Color(red: 0.8, green: 0.0, blue: 0.8),
        Color(red: 0.0, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 1.0, blue: 1.0)
    ])

    static let dark = Palette(colors: [
        Color(red: 0.24, green: 0.24, blue: 0.24),
        Color(red: 1.0, green: 0.42, blue: 0.40),
        Color(red: 0.39, green: 0.91, blue: 0.42),
        Color(red: 0.97, green: 0.89, blue: 0.36),
        Color(red: 0.42, green: 0.65, blue: 1.0),
        Color(red: 0.85, green: 0.44, blue: 1.0),
        Color(red: 0.36, green: 0.89, blue: 0.89),
        Color(red: 0.88, green: 0.88, blue: 0.88),
        Color(red: 0.55, green: 0.55, blue: 0.55),
        Color(red: 1.0, green: 0.54, blue: 0.52),
        Color(red: 0.49, green: 1.0, blue: 0.51),
        Color(red: 1.0, green: 0.94, blue: 0.42),
        Color(red: 0.54, green: 0.71, blue: 1.0),
        Color(red: 0.90, green: 0.57, blue: 1.0),
        Color(red: 0.47, green: 1.0, blue: 1.0),
        Color(red: 1.0, green: 1.0, blue: 1.0)
    ])
}
