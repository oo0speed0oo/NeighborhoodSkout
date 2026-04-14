import SwiftUI

// Fix #2: This is now a navigation page (slides in), not a bottom sheet
// The old version had @Environment(\.dismiss) and a handle bar which conflicted
// with being used as a navigationDestination

struct LineContactSheet: View {
    let block: Block

    var lineResidents: [Person] {
        block.residents.filter { !$0.lineId.isEmpty }
    }

    var body: some View {
        Group {
            if lineResidents.isEmpty { emptyState } else { residentList }
        }
        .navigationTitle("Message on LINE")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    var residentList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.07, green: 0.78, blue: 0.35))
                            .frame(width: 44, height: 44)
                        Text("LINE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.houseName).font(.headline)
                        Text("\(lineResidents.count) LINE contact\(lineResidents.count == 1 ? "" : "s")")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)

                ForEach(lineResidents) { person in
                    LinePersonCard(person: person).padding(.horizontal, 16)
                }
                Spacer(minLength: 40)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.07, green: 0.78, blue: 0.35).opacity(0.12))
                    .frame(width: 72, height: 72)
                Text("LINE")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Color(red: 0.07, green: 0.78, blue: 0.35))
            }
            Text("No LINE IDs saved").font(.title3).fontWeight(.medium)
            Text("Go to Residents and edit each person\nto add their LINE ID")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Person card

struct LinePersonCard: View {
    let person: Person
    @State private var pressed = false

    var body: some View {
        Button(action: { openLine(id: person.lineId) }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(person.gender.color).frame(width: 52, height: 52)
                        .overlay(Circle().stroke(person.gender.borderColor, lineWidth: 1))
                    Text(person.gender.icon).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.fullName).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                    Text(person.role.rawValue).font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 5) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.07, green: 0.78, blue: 0.35))
                                .frame(width: 22, height: 22)
                            Text("L").font(.system(size: 11, weight: .black)).foregroundColor(.white)
                        }
                        Text(person.lineId)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.07, green: 0.55, blue: 0.28))
                    }
                }
                Spacer()
                VStack(spacing: 3) {
                    Image(systemName: "bubble.left.fill").font(.system(size: 20))
                    Text("Chat").font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color(red: 0.07, green: 0.78, blue: 0.35))
                .cornerRadius(14)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.07, green: 0.78, blue: 0.35).opacity(0.2), lineWidth: 1))
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: pressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }

    private func openLine(id: String) {
        let lineURL = URL(string: "line://ti/p/~\(id)")!
        UIApplication.shared.open(lineURL) { success in
            if !success, let webURL = URL(string: "https://line.me/ti/p/~\(id)") {
                UIApplication.shared.open(webURL)
            }
        }
    }
}
