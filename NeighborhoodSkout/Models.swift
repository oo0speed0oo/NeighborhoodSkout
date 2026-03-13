import SwiftUI

// MARK: - Grid Layout Rules
// Each grid defines which columns are valid house positions
// col 0 = left, col 1 = middle, col 2 = right

enum GridLayout {
    case leftAndRight   // Grid 1 & 3: houses on col 0 and col 2, col 1 is road
    case rightOnly      // Grid 2: houses on col 2 only, col 0 and col 1 are road

    func isHouseable(col: Int) -> Bool {
        switch self {
        case .leftAndRight: return col == 0 || col == 2
        case .rightOnly:    return col == 2
        }
    }

    func isRoad(col: Int) -> Bool {
        return !isHouseable(col: col)
    }
}

let gridLayouts: [GridLayout] = [
    .leftAndRight,  // Grid 0
    .rightOnly,     // Grid 1
    .leftAndRight   // Grid 2
]

// MARK: - Person

struct Person: Identifiable, Codable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var gender: Gender
    var birthday: Date
    var role: FamilyRole

    enum Gender: String, Codable, CaseIterable {
        case male   = "Male"
        case female = "Female"
        case other  = "Other"

        var icon: String {
            switch self {
            case .male:   return "👨"
            case .female: return "👩"
            case .other:  return "🧑"
            }
        }
        var color: Color {
            switch self {
            case .male:   return Color(red:0.85,green:0.92,blue:1.0)
            case .female: return Color(red:1.0,green:0.88,blue:0.93)
            case .other:  return Color(red:0.92,green:0.92,blue:0.92)
            }
        }
        var borderColor: Color {
            switch self {
            case .male:   return Color(red:0.38,green:0.60,blue:0.95)
            case .female: return Color(red:0.93,green:0.45,blue:0.65)
            case .other:  return Color(.separator)
            }
        }
    }

    enum FamilyRole: String, Codable, CaseIterable {
        case grandparent = "Grandparent"
        case parent      = "Parent"
        case child       = "Child"
        case other       = "Other"

        var icon: String {
            switch self {
            case .grandparent: return "👴"
            case .parent:      return "👪"
            case .child:       return "🧒"
            case .other:       return "🧑"
            }
        }
    }

    init(id: UUID = UUID(), firstName: String, lastName: String,
         gender: Gender, birthday: Date, role: FamilyRole) {
        self.id        = id
        self.firstName = firstName
        self.lastName  = lastName
        self.gender    = gender
        self.birthday  = birthday
        self.role      = role
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }
    var fullName: String { "\(firstName) \(lastName)" }
}

// MARK: - Block

struct Block: Identifiable, Codable, Equatable {
    let id: UUID
    var houseName: String       // free text e.g. "The Johnsons" or "42 Maple St"
    var colorName: String
    var icon: String
    var gridIndex: Int
    var row: Int
    var col: Int
    var residents: [Person]

    init(id: UUID = UUID(), houseName: String, colorName: String, icon: String,
         gridIndex: Int, row: Int, col: Int) {
        self.id        = id
        self.houseName = houseName
        self.colorName = colorName
        self.icon      = icon
        self.gridIndex = gridIndex
        self.row       = row
        self.col       = col
        self.residents = []
    }
}
