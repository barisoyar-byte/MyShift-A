//
//  Arşiv.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//




import SwiftUI
import SwiftData

// Shared storage keys for initials saved by EkipView
private let ekipInitialsKeyPrimary = "ekip_initials_csv"
private let ekipInitialsKeyFallback = "ekip_initials"
private let ekipInitialsUserKey = "userInitials"

// A simple helper to parse a comma-separated string into initials array
fileprivate func parseInitials(from stored: String) -> [String] {
    let parts = stored
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        .filter { !$0.isEmpty }
    // Keep an empty option at the beginning for "no selection"
    return [""] + parts
}

fileprivate func loadInitialsCSV() -> String {
    let defaults = UserDefaults.standard
    // 1) Prefer the key used in Ekip.swift
    if let user = defaults.string(forKey: ekipInitialsUserKey), !user.isEmpty {
        return user
    }
    // 2) Then try the primary CSV key
    if let primary = defaults.string(forKey: ekipInitialsKeyPrimary), !primary.isEmpty {
        return primary
    }
    // 3) Finally the fallback key
    if let fallback = defaults.string(forKey: ekipInitialsKeyFallback), !fallback.isEmpty {
        return fallback
    }
    // 4) As a last resort, read from the ekip.txt file written by Ekip.swift
    let fm = FileManager.default
    if let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = documentsURL.appendingPathComponent("ekip.txt")
        if let data = try? Data(contentsOf: fileURL), let content = String(data: data, encoding: .utf8) {
            var set = Set<String>()
            for line in content.split(separator: "\n") {
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                if parts.count >= 2 {
                    let initial = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !initial.isEmpty {
                        set.insert(initial)
                    }
                }
            }
            if !set.isEmpty {
                // Keep stable order by sorting; you can change to original order if needed
                let csv = set.sorted().joined(separator: ",")
                return csv
            }
        }
    }
    return ""
}

func importAppStorageFromFileIfAvailable() {
    // Best-effort import of UserDefaults-backed values from a file in Documents.
    // This mirrors the export path and prevents crashes if the file is absent.
    let fm = FileManager.default
    guard let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let fileURL = documentsURL.appendingPathComponent("appstorage.json")
    guard let data = try? Data(contentsOf: fileURL) else { return }
    guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
    let defaults = UserDefaults.standard
    for (k, v) in dict {
        switch v {
        case let s as String: defaults.set(s, forKey: k)
        case let b as Bool: defaults.set(b, forKey: k)
        case let n as NSNumber:
            // Handle Int/Double via NSNumber
            if CFNumberIsFloatType(n) { defaults.set(n.doubleValue, forKey: k) }
            else { defaults.set(n.intValue, forKey: k) }
        default: continue
        }
    }
}

func exportAppStorageToFile() {
    // Persist a small subset of UserDefaults to a JSON file so other views/utilities can read it.
    let defaults = UserDefaults.standard
    let keys = [
        "ekip_initials_csv",
        "ekip_initials",
        "userInitials",
        "archiveLock",
        "selectedTeamIndex"
    ]
    var out: [String: Any] = [:]
    for k in keys {
        if let obj = defaults.object(forKey: k) { out[k] = obj }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted]) else { return }
    let fm = FileManager.default
    guard let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let fileURL = documentsURL.appendingPathComponent("appstorage.json")
    try? data.write(to: fileURL, options: [.atomic])
}

struct ArşivGestureView: View {
    // Example data to make the view compile and previewable
    @State private var entries: [PlanlamaEntry] = []
    @AppStorage(ekipInitialsKeyPrimary) private var storedInitialsCSVPrimary: String = ""
    @AppStorage(ekipInitialsKeyFallback) private var storedInitialsCSVFallback: String = ""
    @AppStorage(ekipInitialsUserKey) private var storedInitialsUser: String = ""
    @AppStorage("archiveLock") private var isLocked: Bool = true
    
    @AppStorage("selectedTeamIndex") private var selectedTeamIndex: Int = 0

    // Begin inserted per-day archive helpers
    
    private struct DayArchive: Codable {
        let date: Date
        let selections: [[String]]
    }

    private func archiveKey(for date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let ts = Int(day.timeIntervalSince1970)
        return "archive_\(selectedTeamIndex)_\(ts)"
    }

    private func saveArchive(for date: Date, selections: [[String]]) {
        let record = DayArchive(date: calendar.startOfDay(for: date), selections: selections)
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: archiveKey(for: date))
        }
    }

    private func loadArchive(for date: Date) -> [[String]]? {
        let key = archiveKey(for: date)
        guard let data = UserDefaults.standard.data(forKey: key),
              let record = try? JSONDecoder().decode(DayArchive.self, from: data) else { return nil }
        return record.selections
    }
    // End inserted per-day archive helpers
    
    @State private var teams: [String] = ["A", "B", "C", "D", "E"]
    @State private var selectedDate: Date = Date()
    @State private var selectedDay: Date? = nil
    private let calendar = Calendar.current
    
    private var minDate: Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        return calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
    private var maxDate: Date { calendar.startOfDay(for: Date()) }
    
    @State private var selections: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 10)
    
    private var initials: [String] {
        let csv: String
        if !storedInitialsUser.isEmpty {
            csv = storedInitialsUser
        } else if !storedInitialsCSVPrimary.isEmpty {
            csv = storedInitialsCSVPrimary
        } else if !storedInitialsCSVFallback.isEmpty {
            csv = storedInitialsCSVFallback
        } else {
            csv = loadInitialsCSV()
        }
        let parsed = parseInitials(from: csv)
        return parsed.count > 1 ? parsed : ["", "(Ekip ayarlarından initial ekleyin)"]
    }
    
    private func labelFor(row: Int, col: Int) -> String {
        if col == 0 {
            switch row {
            case 0: return " "
            case 1: return "Saat"
            case 2: return "08:30"
            case 3: return "10:30"
            case 4: return "12:30"
            case 5: return "14:30"
            case 6: return "16:30"
            case 7: return "18:30"
            case 8: return "NOTAM"
            case 9: return "İzin/Mazeret/\nRapor/Görev"
            default: return ""
            }
        } else {
            switch col {
            case 1: return "EXE"
            case 2: return "PLN"
            case 3: return "OJTI"
            case 4: return "EXE"
            case 5: return "PLN"
            case 6: return "OJTI"
            default: return ""
            }
        }
    }
    
    private func bindingForSelection(row: Int, col: Int) -> Binding<String> {
        Binding<String>(
            get: { selections[row][col] },
            set: { selections[row][col] = $0 }
        )
    }
    
    private func isDuplicateInitial(at row: Int, col: Int) -> Bool {
        // Exclude the last row entirely
        if row == 9 { return false }
        // Only apply to valid data columns
        guard (1...6).contains(col) else { return false }
        let current = selections[row][col]
        if current.isEmpty { return false }

        // Helper to decide if two positions should be compared, taking NOTAM/ARI exception into account
        func shouldCompare(_ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> Bool {
            // Same cell, skip
            if r1 == r2 && c1 == c2 { return false }
            // Allow NOTAM and ARI to be the same: row 8 has NOTAM group across columns (2..4) and ARI at column 6
            // If both positions are on row 8 and one is in NOTAM group and the other is ARI column, ignore comparison
            if r1 == 8 && r2 == 8 {
                let isNotam1 = (2...4).contains(c1)
                let isAri1 = (c1 == 6)
                let isNotam2 = (2...4).contains(c2)
                let isAri2 = (c2 == 6)
                if (isNotam1 && isAri2) || (isAri1 && isNotam2) {
                    return false
                }
            }
            return true
        }

        // Check duplicates in the same row
        var sameRowCount = 0
        for c in 1...6 {
            if shouldCompare(row, col, row, c) && selections[row][c] == current {
                sameRowCount += 1
            }
        }
        if sameRowCount > 0 { return true }

        // Check previous and next rows if they exist and are not the excluded last row
        let neighbors = [row - 1, row + 1].filter { (2...7).contains($0) }
        for r in neighbors {
            for c in 1...6 {
                if shouldCompare(row, col, r, c) && selections[r][c] == current {
                    return true
                }
            }
        }
        return false
    }
    
    private func moveTeam(by offset: Int) {
        guard !teams.isEmpty else { return }
        selectedTeamIndex = (selectedTeamIndex + offset + teams.count) % teams.count
    }

    private func changeMonth(by offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: selectedDate) {
            // Determine the start and end of the target month
            guard let startOfNewMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate)),
                  let range = calendar.range(of: .day, in: .month, for: newDate) else { return }
            let endOfNewMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfNewMonth)!

            // If the whole target month is after maxDate or before minDate, block
            if startOfNewMonth > maxDate { return }
            if endOfNewMonth < minDate { return }

            // Clamp selectedDate into the allowed range
            let clamped = min(max(newDate, minDate), maxDate)
            selectedDate = clamped
        }
    }
    
    private func changeDay(by offset: Int) {
        if let newDate = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
            let day = calendar.startOfDay(for: newDate)
            if day < calendar.startOfDay(for: minDate) { return }
            if day > maxDate { return }
            selectedDate = newDate
        }
    }

    private func monthYearString(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date).capitalized
    }

    private func daysInMonth(of date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }

    private func weekdayShort(for date: Date) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let idx = calendar.component(.weekday, from: date) - 1
        return symbols[idx]
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func isBlueDay(_ date: Date) -> Bool {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        guard let anchor = calendar.date(from: comps) else { return false }
        // Shift based on selected team with custom mapping:
        // A=0, B=-1, C=-2, D=-3, E=-4
        let teamShift: Int = {
            switch selectedTeamIndex {
            case 0: return 0   // A
            case 1: return -1  // B
            case 2: return -2  // C
            case 3: return -3  // D
            case 4: return -4  // E
            default: return 0
            }
        }()
        let shiftedDate = calendar.date(byAdding: .day, value: teamShift, to: date) ?? date
        guard let days = calendar.dateComponents([.day], from: anchor, to: shiftedDate).day else { return false }
        return days % 5 == 0
    }

    private func isRedDay(_ date: Date) -> Bool {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 5
        guard let anchor = calendar.date(from: comps) else { return false }
        // Shift based on selected team with custom mapping:
        // A=0, B=-1, C=-2, D=-3, E=-4
        let teamShift: Int = {
            switch selectedTeamIndex {
            case 0: return 0   // A
            case 1: return -1  // B
            case 2: return -2  // C
            case 3: return -3  // D
            case 4: return -4  // E
            default: return 0
            }
        }()
        let shiftedDate = calendar.date(byAdding: .day, value: teamShift, to: date) ?? date
        guard let days = calendar.dateComponents([.day], from: anchor, to: shiftedDate).day else { return false }
        return days % 5 == 0
    }
    
    private struct DayChip: View {
        let day: Date
        let calendar: Calendar
        let isRed: Bool
        let isBlue: Bool
        let isToday: Bool
        let isSelected: Bool
        let onTap: () -> Void

        var body: some View {
            let isSelectable = isRed || isBlue
            let textColor: Color = {
                if isRed { return .red }
                if isBlue { return .blue }
                return .primary
            }()
            let borderColor: Color = {
                if isToday { return .blue }
                if isRed { return .red }
                if isBlue { return .blue }
                return Color.gray.opacity(0.3)
            }()
            let borderWidth: CGFloat = isToday ? 2 : 1

            VStack(spacing: 4) {
                Text(weekdayShortStatic(for: day, calendar: calendar))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(calendar.component(.day, from: day)))
                    .font(.headline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : (isToday ? Color.yellow.opacity(0.25) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : borderColor, lineWidth: isSelected ? 3 : borderWidth)
            )
            .foregroundStyle(textColor)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isSelectable ? 1.0 : 0.4)
            .onTapGesture { onTap() }
            .allowsHitTesting(isSelectable)
        }

        private func weekdayShortStatic(for date: Date, calendar: Calendar) -> String {
            let symbols = calendar.shortWeekdaySymbols
            let idx = calendar.component(.weekday, from: date) - 1
            return symbols[idx]
        }
    }
    
    struct ArşivView: View {
        @Binding var selections: [[String]]
        let initials: [String]
        let labelFor: (Int, Int) -> String
        let bindingForSelection: (Int, Int) -> Binding<String>
        let isLocked: Bool
        
        private struct PickerCell: View {
            let binding: Binding<String>
            let options: [String]
            let tintColor: Color?
            var body: some View {
                HStack(spacing: 6) {
                    Picker("", selection: binding) {
                        ForEach(options, id: \.self) { item in
                            HStack {
                                Text(item)
                                Spacer()
                                if item == binding.wrappedValue && !item.isEmpty {
                                    // no checkmark; keep clean
                                }
                            }
                            .tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(tintColor ?? .accentColor)

                    Spacer(minLength: 0)
                }
            }
        }
        
        var body: some View {
            VStack(spacing: 16) {
                ScrollView([.vertical, .horizontal]) {
                    Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text(" ")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)

                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("MLO")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            .gridCellColumns(3)

                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("MUW")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            .gridCellColumns(3)
                        }

                        GridRow {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text(labelFor(1, 0))
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)

                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("EXE")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("PLN")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("OJTI")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("EXE")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("PLN")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("OJTI")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)
                        }

                        ForEach(2..<10, id: \.self) { row in
                            GridRow {
                                if row == 8 {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text(labelFor(row, 0))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(isLocked ? .secondary : .primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 9 ? 72 : 36)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 2), options: initials, tintColor: nil)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 9 ? 72 : 36)
                                    .gridCellColumns(3)
                                    .disabled(isLocked)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text("ARI")
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(isLocked ? .secondary : .primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 9 ? 72 : 36)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 6), options: initials, tintColor: nil)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 9 ? 72 : 36)
                                    .gridCellColumns(2)
                                    .disabled(isLocked)
                                } else if row == 9 {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text(labelFor(row, 0))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(isLocked ? .secondary : .primary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: 72)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text("")
                                    }
                                    .frame(minWidth: 80, minHeight: 72)
                                    .gridCellColumns(6)
                                } else {
                                    ForEach(0..<7, id: \.self) { col in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                            if row >= 1 && col >= 1 {
                                                PickerCell(
                                                    binding: bindingForSelection(row, col),
                                                    options: initials,
                                                    tintColor: nil
                                                )
                                                .disabled(isLocked)
                                            } else {
                                                let labelText = labelFor(row, col)
                                                Text(labelText)
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundStyle(isLocked ? .secondary : .primary)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.8)
                                                    .padding(4)
                                            }
                                        }
                                        .frame(minWidth: 80, minHeight: row == 9 ? 72 : 36)
                                    }
                                }
                            }
                        }
                    }
                }

                List { EmptyView() }
                    .listStyle(.plain)
                    .frame(height: 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with title and navigation buttons
            HStack {
                Button(action: { if !isLocked { moveTeam(by: -1) } }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isLocked ? .secondary : .primary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Text(teams[selectedTeamIndex])
                        .font(.title.weight(.bold))
                        .foregroundStyle(isLocked ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.blue))
                    Button(action: { isLocked.toggle() }) {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isLocked ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.blue))
                            .accessibilityLabel(isLocked ? "Kilitli" : "Kilidi Açık")
                    }
                }
                Spacer()
                Button(action: { if !isLocked { moveTeam(by: 1) } }) {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isLocked ? .secondary : .primary)
                }
            }
            .padding(.horizontal)

            // Month navigation and single-row days strip
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill").font(.title3)
                }
                Spacer()
                Text(monthYearString(for: selectedDate))
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill").font(.title3)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(daysInMonth(of: selectedDate).filter { day in
                        return day >= calendar.startOfDay(for: minDate) && day <= maxDate
                    }, id: \.self) { day in
                        DayChip(
                            day: day,
                            calendar: calendar,
                            isRed: isRedDay(day),
                            isBlue: isBlueDay(day),
                            isToday: calendar.isDateInToday(day),
                            isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false,
                            onTap: {
                                let isSelectable = isRedDay(day) || isBlueDay(day)
                                if isSelectable {
                                    selectedDay = day
                                    if let loaded = loadArchive(for: day) {
                                        selections = loaded
                                    } else {
                                        selections = Array(repeating: Array(repeating: "", count: 7), count: 10)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            ArşivView(
                selections: $selections,
                initials: initials,
                labelFor: { row, col in labelFor(row: row, col: col) },
                bindingForSelection: { row, col in bindingForSelection(row: row, col: col) },
                isLocked: isLocked
            )
        }
        .padding()
        .onAppear {
            importAppStorageFromFileIfAvailable()

            let today = calendar.startOfDay(for: Date())
            selectedDay = today
            if let loaded = loadArchive(for: today) {
                selections = loaded
            }
        }
        .onChange(of: storedInitialsCSVPrimary, initial: false) { _, _ in exportAppStorageToFile() }
        .onChange(of: storedInitialsCSVFallback, initial: false) { _, _ in exportAppStorageToFile() }
        .onChange(of: storedInitialsUser, initial: false) { _, _ in exportAppStorageToFile() }
        .onChange(of: isLocked, initial: false) { _, _ in exportAppStorageToFile() }
        .onChange(of: selectedTeamIndex, initial: false) { _, _ in
            exportAppStorageToFile()
            if let d = selectedDay, let loaded = loadArchive(for: d) {
                selections = loaded
            } else {
                selections = Array(repeating: Array(repeating: "", count: 7), count: 10)
            }
        }
        .onChange(of: selectedDay, initial: false) { _, newDay in
            if let d = newDay, let loaded = loadArchive(for: d) { selections = loaded }
        }
        .onChange(of: selections, initial: false) { _, _ in
            if !isLocked, let day = selectedDay {
                saveArchive(for: day, selections: selections)
            }
        }
    }
}


#Preview("Planlama") {
    NavigationStack { ArşivGestureView() }
}

#Preview("Takvim") {
    TakvimWrapperView()
}

