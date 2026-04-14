import SwiftUI

// MARK: - CSV Format
// Two section types in the same file:
//
// STREET rows (7 columns):
// #STREET,Name,Template,Rows,,,
// Example: #STREET,Maple Street,Houses Both Sides,5,,,
//
// BLOCK/PERSON rows (12 columns):
// HouseName,GridIndex,Row,Col,ColorName,Icon,FirstName,LastName,Gender,Role,Birthday,LineID
// Example: The Smiths,0,0,0,purple,🏠,John,Smith,Male,Parent,1980-01-15,johnsmith

struct CSVManager {

    static var csvURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("neighborhood_data.csv")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Build CSV string (used for saving back to iCloud)

    static func buildContent(blocks: [Block], streets: [Street]) -> String {
        var lines: [String] = []
        lines.append("#STREET,Name,Template,Rows,,,")
        for street in streets {
            lines.append("#STREET,\(escape(street.name)),\(escape(street.template.rawValue)),\(street.rows),,,")
        }
        lines.append("HouseName,GridIndex,Row,Col,ColorName,Icon,FirstName,LastName,Gender,Role,Birthday,LineID")
        for block in blocks {
            if block.residents.isEmpty {
                let row = [escape(block.houseName), "\(block.gridIndex)", "\(block.row)", "\(block.col)",
                           block.colorName, block.icon, "", "", "", "", "", ""].joined(separator: ",")
                lines.append(row)
            } else {
                for person in block.residents {
                    let row = [escape(block.houseName), "\(block.gridIndex)", "\(block.row)", "\(block.col)",
                               block.colorName, block.icon,
                               escape(person.firstName), escape(person.lastName),
                               person.gender.rawValue, person.role.rawValue,
                               dateFormatter.string(from: person.birthday),
                               escape(person.lineId)].joined(separator: ",")
                    lines.append(row)
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Save

    static func save(blocks: [Block], streets: [Street]) {
        let content = buildContent(blocks: blocks, streets: streets)
        try? content.write(to: csvURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Load from Documents

    static func load() -> (blocks: [Block], streets: [Street])? {
        guard let content = try? String(contentsOf: csvURL, encoding: .utf8) else { return nil }
        return parse(content: content)
    }

    // MARK: - Load from any URL

    static func loadFrom(url: URL) -> (blocks: [Block], streets: [Street])? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ CSVManager: could not read \(url.lastPathComponent)")
            return nil
        }
        return parse(content: content)
    }

    // MARK: - Parse

    static func parse(content: String) -> (blocks: [Block], streets: [Street])? {
        var allLines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !allLines.isEmpty else { return nil }

        var streets: [Street] = []
        var blockLines: [String] = []
        var inBlockSection = false

        for line in allLines {
            if line.hasPrefix("#STREET,") {
                let cols = parseLine(line)
                guard cols.count >= 4 else { continue }
                let name     = unescape(cols[1])
                let tmplRaw  = unescape(cols[2])
                let rows     = Int(cols[3]) ?? 5
                let template = StreetTemplate(rawValue: tmplRaw) ?? .bothSides
                streets.append(Street(name: name, template: template, rows: rows))
            } else if line.hasPrefix("HouseName,") {
                inBlockSection = true
            } else if inBlockSection {
                blockLines.append(line)
            }
        }

        // If no #STREET rows found (old CSV format), create default streets
        if streets.isEmpty {
            streets = defaultStreets()
        }

        var blockMap: [String: Block] = [:]
        var skipped = 0

        for line in blockLines {
            let cols = parseLine(line)
            guard cols.count >= 6 else { skipped += 1; continue }

            let houseName = unescape(cols[0])
            let gridIndex = Int(cols[1]) ?? 0
            let row       = Int(cols[2]) ?? 0
            let col       = Int(cols[3]) ?? 0
            let colorName = cols[4]
            let icon      = cols[5]
            let key       = "\(gridIndex)-\(row)-\(col)"

            if blockMap[key] == nil {
                blockMap[key] = Block(houseName: houseName, colorName: colorName, icon: icon,
                                      gridIndex: gridIndex, row: row, col: col)
            }

            if cols.count >= 11, !cols[6].isEmpty,
               let gender   = Person.Gender(rawValue: cols[8]),
               let role     = Person.FamilyRole(rawValue: cols[9]),
               let birthday = dateFormatter.date(from: cols[10]) {
                let lineId = cols.count >= 12 ? unescape(cols[11]) : ""
                let person = Person(firstName: unescape(cols[6]), lastName: unescape(cols[7]),
                                    gender: gender, birthday: birthday, role: role, lineId: lineId)
                blockMap[key]?.residents.append(person)
            }
        }

        let blocks = blockMap.values.sorted {
            if $0.gridIndex != $1.gridIndex { return $0.gridIndex < $1.gridIndex }
            if $0.row != $1.row { return $0.row < $1.row }
            return $0.col < $1.col
        }

        print("✅ CSVManager: \(streets.count) streets, \(blocks.count) blocks, skipped \(skipped)")
        return (blocks: blocks, streets: streets)
    }

    // MARK: - Default streets (for blank template / old CSV compatibility)

    static func defaultStreets() -> [Street] {
        return [
            Street(name: "Street 1", template: .bothSides, rows: 5),
            Street(name: "Street 2", template: .rightOnly,  rows: 5),
            Street(name: "Street 3", template: .bothSides,  rows: 5),
        ]
    }

    // MARK: - Blank template CSV (for new users)

    static func blankTemplateContent() -> String {
        var lines: [String] = []
        let streets = defaultStreets()
        lines.append("#STREET,Name,Template,Rows,,,")
        for s in streets {
            lines.append("#STREET,\(s.name),\(s.template.rawValue),\(s.rows),,,")
        }
        lines.append("HouseName,GridIndex,Row,Col,ColorName,Icon,FirstName,LastName,Gender,Role,Birthday,LineID")
        // Add empty house slots for all valid positions
        let colors = ["purple","teal","coral","pink","blue","green","orange","red"]
        let icons  = ["🏠","🏡","🏘","🏚","🏗","🏢","🏣","🏤"]
        var idx = 0
        for (gIdx, street) in streets.enumerated() {
            let cfg = street.config
            for r in 0..<cfg.rows {
                for c in 0..<cfg.cols {
                    if cfg.isHouseable(row: r, col: c) {
                        let color = colors[idx % colors.count]
                        let icon  = icons[idx % icons.count]
                        lines.append("House \(idx + 1),\(gIdx),\(r),\(c),\(color),\(icon),,,,,,")
                        idx += 1
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    static var csvPath: String { csvURL.path }

    // MARK: - Helpers

    static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    static func unescape(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("\"") && t.hasSuffix("\"") {
            t = String(t.dropFirst().dropLast())
            t = t.replacingOccurrences(of: "\"\"", with: "\"")
        }
        return t
    }

    static func parseLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        result.append(current)
        return result
    }
}
