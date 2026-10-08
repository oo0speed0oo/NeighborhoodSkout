import UserNotifications
import Foundation

final class BirthdayNotificationManager {
    static let shared = BirthdayNotificationManager()
    private init() {}

    private let center   = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private let hourKey      = "nsk_notifHour"
    private let minuteKey    = "nsk_notifMinute"
    private let dayBeforeKey = "nsk_notifDayBefore"

    var notifHour: Int {
        defaults.object(forKey: hourKey) == nil ? 9 : defaults.integer(forKey: hourKey)
    }
    var notifMinute: Int  { defaults.integer(forKey: minuteKey) }
    var notifDayBefore: Bool { defaults.bool(forKey: dayBeforeKey) }

    func setTime(hour: Int, minute: Int) {
        defaults.set(hour,   forKey: hourKey)
        defaults.set(minute, forKey: minuteKey)
    }
    func setDayBefore(_ on: Bool) { defaults.set(on, forKey: dayBeforeKey) }

    // MARK: - Permission

    func requestPermissionIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion?(granted) }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion?(true) }
            default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    // MARK: - Schedule all birthday notifications

    func scheduleAll(blocks: [Block], streets: [Street]) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }
            self.doSchedule(blocks: blocks, streets: streets)
        }
    }

    private func doSchedule(blocks: [Block], streets: [Street]) {
        let cal       = Calendar.current
        let now       = Date()
        let hour      = notifHour
        let minute    = notifMinute
        let dayBefore = notifDayBefore

        // Build (person, streetName, nextDate) entries
        struct Entry {
            let personId:   UUID
            let firstName:  String
            let streetName: String
            let nextDate:   Date   // exact fire time for the "today" notification
            let birthday:   Date
        }
        var entries: [Entry] = []

        for block in blocks {
            let streetName = streets.indices.contains(block.gridIndex) ? streets[block.gridIndex].name : ""
            for person in block.residents {
                guard let next = nextBirthday(of: person.birthday, after: now,
                                              hour: hour, minute: minute) else { continue }
                entries.append(Entry(personId: person.id, firstName: person.firstName,
                                     streetName: streetName, nextDate: next,
                                     birthday: person.birthday))
            }
        }

        entries.sort { $0.nextDate < $1.nextDate }

        // iOS limit is 64; keep 4 in reserve for other app use
        let slotsPerBirthday = dayBefore ? 2 : 1
        let maxBirthdays     = 60 / slotsPerBirthday
        let toSchedule       = entries.prefix(maxBirthdays)

        center.removeAllPendingNotificationRequests()

        for entry in toSchedule {
            let age = ageAt(birthday: entry.birthday, on: entry.nextDate)

            // Same-day notification
            schedule(id:      "bday-\(entry.personId.uuidString)-today",
                     title:   "🎂 Birthday",
                     body:    "\(entry.firstName) from \(entry.streetName) turns \(age) today.",
                     on:      entry.nextDate)

            if dayBefore {
                let eve = entry.nextDate.addingTimeInterval(-86400)
                schedule(id:      "bday-\(entry.personId.uuidString)-eve",
                         title:   "🎂 Birthday Tomorrow",
                         body:    "\(entry.firstName) from \(entry.streetName) turns \(age) tomorrow.",
                         on:      eve)
            }
        }
    }

    private func schedule(id: String, title: String, body: String, on date: Date) {
        let content       = UNMutableNotificationContent()
        content.title     = title
        content.body      = body
        content.sound     = .default
        let comps         = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger       = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request       = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Test notification (fires in 5 seconds)

    func fireTestNotification(firstName: String, streetName: String, age: Int) {
        let content   = UNMutableNotificationContent()
        content.title = "🎂 Birthday (Test)"
        content.body  = "\(firstName) from \(streetName) turns \(age) today."
        content.sound = .default
        let trigger   = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request   = UNNotificationRequest(identifier: "bday-test-\(UUID().uuidString)",
                                              content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Helpers

    private func nextBirthday(of birthday: Date, after now: Date,
                               hour: Int, minute: Int) -> Date? {
        let cal   = Calendar.current
        var comps = cal.dateComponents([.month, .day], from: birthday)
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        comps.year   = cal.component(.year, from: now)
        guard var candidate = cal.date(from: comps) else { return nil }
        if candidate <= now {
            comps.year = (comps.year ?? 0) + 1
            candidate  = cal.date(from: comps) ?? candidate
        }
        return candidate
    }

    private func ageAt(birthday: Date, on date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: birthday, to: date).year ?? 0
    }
}
