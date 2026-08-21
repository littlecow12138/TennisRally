import SwiftUI
import UIKit

enum HardCourt {
    private static func dynamic(dark: UIColor, light: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static let darkBG = UIColor(red: 0.047, green: 0.086, blue: 0.071, alpha: 1) // #0C1612
    private static let lightBG = UIColor(red: 0.957, green: 0.965, blue: 0.953, alpha: 1) // #F4F6F3
    private static let darkSurface = UIColor(red: 0.082, green: 0.141, blue: 0.110, alpha: 1) // #15241C
    private static let lightSurface = UIColor(red: 0.910, green: 0.894, blue: 0.863, alpha: 1) // #E8E4DC
    private static let accentUI = UIColor(red: 0.784, green: 0.910, blue: 0.227, alpha: 1) // #C8E83A
    private static let chalkUI = UIColor(red: 0.910, green: 0.894, blue: 0.863, alpha: 1) // #E8E4DC
    private static let darkText = UIColor(red: 0.957, green: 0.965, blue: 0.953, alpha: 1) // #F4F6F3
    private static let lightText = UIColor(red: 0.047, green: 0.086, blue: 0.071, alpha: 1) // #0C1612
    private static let darkMuted = UIColor(red: 0.541, green: 0.604, blue: 0.565, alpha: 1) // #8A9A90
    private static let lightMuted = UIColor(red: 0.353, green: 0.420, blue: 0.376, alpha: 1) // #5A6B60

    static let bg = dynamic(dark: darkBG, light: lightBG)
    static let surface = dynamic(dark: darkSurface, light: lightSurface)
    static let accent = Color(accentUI)
    static let chalk = Color(chalkUI)
    static let text = dynamic(dark: darkText, light: lightText)
    static let muted = dynamic(dark: darkMuted, light: lightMuted)
    static let danger = Color(red: 0.91, green: 0.40, blue: 0.30)
    static let hairline = dynamic(
        dark: UIColor.white.withAlphaComponent(0.08),
        light: darkBG.withAlphaComponent(0.10)
    )
    static let courtLine = dynamic(
        dark: chalkUI.withAlphaComponent(0.08),
        light: darkBG.withAlphaComponent(0.08)
    )
}
