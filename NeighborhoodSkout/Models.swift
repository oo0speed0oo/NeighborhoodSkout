import SwiftUI

// MARK: - Street Layout Templates

enum StreetTemplate: String, Codable, CaseIterable {
    case bothSides  = "Houses Both Sides"
    case leftOnly   = "Houses Left Side"
    case rightOnly  = "Houses Right Side"
    case culDeSac   = "Cul-de-sac"

    var icon: String {
        switch self {
        case .bothSides: return "🏘"
        case .leftOnly:  return "🏠"
        case .rightOnly: return "🏡"
        case .culDeSac:  return "🔵"
        }
    }

    var description: String {
        switch self {
        case .bothSides: return "Houses on both sides of the road"
        case .leftOnly:  return "Houses on the left side only"
        case .rightOnly: return "Houses on the right side only"
        case .culDeSac:  return "Houses on both sides, no road divider"
        }
    }

    func makeConfig(rows: Int = 5) -> GridConfig {
        switch self {
        case .bothSides:
            return GridConfig(rows: rows, cols: 3, houseableCols: [0, 2], roadCols: [1], extraHouseableCells: [])
        case .leftOnly:
            return GridConfig(rows: rows, cols: 3, houseableCols: [0], roadCols: [1, 2], extraHouseableCells: [])
        case .rightOnly:
            return GridConfig(rows: rows, cols: 3, houseableCols: [2], roadCols: [0, 1], extraHouseableCells: [])
        case .culDeSac:
            return GridConfig(rows: rows, cols: 2, houseableCols: [0, 1], roadCols: [], extraHouseableCells: [])
        }
    }
}

// MARK: - Street

struct Street: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var template: StreetTemplate
    var rows: Int

    init(id: UUID = UUID(), name: String, template: StreetTemplate, rows: Int = 5) {
        self.id = id; self.name = name; self.template = template; self.rows = rows
    }

    var config: GridConfig { template.makeConfig(rows: rows) }
}

// MARK: - GridConfig (built dynamically from Street)

struct GridConfig {
    let rows: Int
    let cols: Int
    let houseableCols: Set<Int>
    let roadCols: Set<Int>
    let extraHouseableCells: Set<String>

    func isHouseable(row: Int, col: Int) -> Bool {
        if extraHouseableCells.contains("\(row)-\(col)") { return true }
        return houseableCols.contains(col)
    }
    func isRoad(row: Int, col: Int) -> Bool {
        if isHouseable(row: row, col: col) { return false }
        return roadCols.contains(col)
    }
    func isBlank(row: Int, col: Int) -> Bool {
        !isHouseable(row: row, col: col) && !isRoad(row: row, col: col)
    }
}

// MARK: - Person

struct Person: Identifiable, Codable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var gender: Gender
    var birthday: Date
    var role: FamilyRole
    var lineId: String

    enum Gender: String, Codable, CaseIterable {
        case male   = "Male"
        case female = "Female"
        case other  = "Other"
        var icon: String {
            switch self { case .male: return "👨"; case .female: return "👩"; case .other: return "🧑" }
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
         gender: Gender, birthday: Date, role: FamilyRole, lineId: String = "") {
        self.id = id; self.firstName = firstName; self.lastName = lastName
        self.gender = gender; self.birthday = birthday; self.role = role; self.lineId = lineId
    }

    var age: Int { Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0 }
    var fullName: String { "\(firstName) \(lastName)" }
}

// MARK: - Block

struct Block: Identifiable, Codable, Equatable {
    let id: UUID
    var houseName: String
    var colorName: String
    var icon: String
    var gridIndex: Int
    var row: Int
    var col: Int
    var residents: [Person]

    init(id: UUID = UUID(), houseName: String, colorName: String, icon: String,
         gridIndex: Int, row: Int, col: Int) {
        self.id = id; self.houseName = houseName; self.colorName = colorName
        self.icon = icon; self.gridIndex = gridIndex; self.row = row; self.col = col
        self.residents = []
    }
}
