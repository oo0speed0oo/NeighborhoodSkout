import SwiftUI

extension Color {
    // Grass background for the map — adapts to dark mode
    static let mapGrass = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.24, blue: 0.12, alpha: 1)
            : UIColor(red: 0.52, green: 0.76, blue: 0.38, alpha: 1)
    })

    static func blockBackground(_ n: String) -> Color {
        switch n {
        case "purple": return Color(red:0.93,green:0.93,blue:0.996)
        case "teal":   return Color(red:0.88,green:0.96,blue:0.93)
        case "coral":  return Color(red:0.98,green:0.93,blue:0.91)
        case "pink":   return Color(red:0.98,green:0.92,blue:0.94)
        case "blue":   return Color(red:0.90,green:0.94,blue:1.0)
        case "green":  return Color(red:0.90,green:0.96,blue:0.88)
        case "orange": return Color(red:1.0, green:0.94,blue:0.86)
        case "red":    return Color(red:1.0, green:0.91,blue:0.91)
        default:       return Color(.systemGray6)
        }
    }
    static func blockBorder(_ n: String) -> Color {
        switch n {
        case "purple": return Color(red:0.69,green:0.66,blue:0.93)
        case "teal":   return Color(red:0.36,green:0.79,blue:0.65)
        case "coral":  return Color(red:0.94,green:0.60,blue:0.48)
        case "pink":   return Color(red:0.93,green:0.58,blue:0.69)
        case "blue":   return Color(red:0.38,green:0.60,blue:0.95)
        case "green":  return Color(red:0.40,green:0.72,blue:0.38)
        case "orange": return Color(red:0.95,green:0.65,blue:0.28)
        case "red":    return Color(red:0.90,green:0.40,blue:0.40)
        default:       return Color(.separator)
        }
    }
    static func blockText(_ n: String) -> Color {
        switch n {
        case "purple": return Color(red:0.24,green:0.20,blue:0.54)
        case "teal":   return Color(red:0.03,green:0.31,blue:0.25)
        case "coral":  return Color(red:0.29,green:0.11,blue:0.05)
        case "pink":   return Color(red:0.29,green:0.08,blue:0.16)
        case "blue":   return Color(red:0.08,green:0.25,blue:0.65)
        case "green":  return Color(red:0.10,green:0.38,blue:0.10)
        case "orange": return Color(red:0.50,green:0.28,blue:0.02)
        case "red":    return Color(red:0.55,green:0.10,blue:0.10)
        default:       return Color(.label)
        }
    }
}
