//
//  Planlama.swift
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

// Removed duplicate PlanlamaEntry struct here

struct PlanlamaView: View {
    // Example data to make the view compile and previewable
    @State private var entries: [PlanlamaEntry] = []
    @AppStorage(ekipInitialsKeyPrimary) private var storedInitialsCSVPrimary: String = ""
    @AppStorage(ekipInitialsKeyFallback) private var storedInitialsCSVFallback: String = ""
    @AppStorage(ekipInitialsUserKey) private var storedInitialsUser: String = ""
    
    @State private var teams: [String] = ["A", "B", "C", "D", "E"]
    @AppStorage("selectedTeamIndex") private var selectedTeamIndex: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var selectedDay: Date? = nil
    private let calendar = Calendar.current
    
    // Insert new helper functions for per-day storage here
    private func dayKey(for date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let ts = Int(day.timeIntervalSince1970)
        return "planlama_day_\(selectedTeamIndex)_\(ts)"
    }

    private func saveDaySelections(for date: Date) {
        let key = dayKey(for: date)
        if let data = try? JSONEncoder().encode(selections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadDaySelections(for date: Date) -> [[String]]? {
        let key = dayKey(for: date)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([[String]].self, from: data) else { return nil }
        return decoded
    }

    @State private var selections: [[String]] = Array(repeating: Array(repeating: "", count: 7), count: 10)
    @State private var monthMatrix: [[String]] = []
    
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
        for c in 1...6 {
            if shouldCompare(row, col, row, c) && selections[row][c] == current {
                return true
            }
        }

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
            // Do not allow navigating to months entirely before yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
            let startOfNewMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate))!
            // If the end of the new month is still before yesterday, block
            let range = calendar.range(of: .day, in: .month, for: newDate)!
            let lastDay = calendar.date(byAdding: .day, value: range.count - 1, to: startOfNewMonth)!
            if lastDay < calendar.startOfDay(for: yesterday) {
                return
            }
            selectedDate = newDate
            
            if let first = firstSelectableDay(in: newDate) {
                selectedDay = first
            } else {
                selectedDay = nil
            }
        }
    }
    
    private func changeDay(by offset: Int) {
        if let newDate = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
            if calendar.startOfDay(for: newDate) < calendar.startOfDay(for: yesterday) {
                return
            }
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
    
    private func firstSelectableDay(in month: Date) -> Date? {
        for day in daysInMonth(of: month) {
            if isRedDay(day) || isBlueDay(day) {
                return day
            }
        }
        return nil
    }

    private func nearestSelectableDay(in month: Date, from reference: Date) -> Date? {
        let days = daysInMonth(of: month)
        guard !days.isEmpty else { return nil }
        let ref = calendar.startOfDay(for: reference)
        var bestDay: Date? = nil
        var bestDistance: Int = Int.max
        for day in days {
            if isRedDay(day) || isBlueDay(day) {
                if let dist = calendar.dateComponents([.day], from: ref, to: day).day.map({ abs($0) }) {
                    if dist < bestDistance {
                        bestDistance = dist
                        bestDay = day
                    }
                }
            }
        }
        return bestDay
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
    
    private func ensureMonthMatrixRows(initials: [String], dayCount: Int) {
        let nonEmptyInitials = initials.filter { !$0.isEmpty }
        let targetRows = nonEmptyInitials.count + 1
        let targetCols = dayCount
        guard targetCols > 0 else {
            monthMatrix = Array(repeating: Array(repeating: "", count: 0), count: targetRows)
            return
        }
        if monthMatrix.count != targetRows {
            monthMatrix = Array(repeating: Array(repeating: "", count: targetCols), count: targetRows)
        } else {
            for r in 0..<monthMatrix.count {
                if monthMatrix[r].count != targetCols {
                    if monthMatrix[r].count < targetCols {
                        monthMatrix[r].append(contentsOf: Array(repeating: "", count: targetCols - monthMatrix[r].count))
                    } else {
                        monthMatrix[r] = Array(monthMatrix[r].prefix(targetCols))
                    }
                }
            }
        }
    }

    private func matrixStorageKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        return "matrix_\(y)\(String(format: "%02d", m))"
    }

    private func saveMonthMatrix(for date: Date) {
        let key = matrixStorageKey(for: date)
        if let data = try? JSONEncoder().encode(monthMatrix) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadMonthMatrix(for date: Date) {
        let key = matrixStorageKey(for: date)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([[String]].self, from: data) {
            monthMatrix = decoded
        }
    }
    
    private struct DayPill: View {
        let day: Date
        let calendar: Calendar
        let isRed: Bool
        let isBlue: Bool
        let isToday: Bool
        let isSelected: Bool
        let onTap: () -> Void

        private var textColor: Color {
            if isRed { return .red }
            if isBlue { return .blue }
            return .primary
        }

        private var borderColor: Color {
            if isSelected { return Color.accentColor }
            if isToday { return .blue }
            if isRed { return .red }
            if isBlue { return .blue }
            return Color.gray.opacity(0.3)
        }

        private var borderWidth: CGFloat { isToday ? 2 : 1 }

        private var backgroundFill: Color {
            isSelected ? Color.accentColor.opacity(0.25) : (isToday ? Color.yellow.opacity(0.25) : Color.clear)
        }

        private func weekdayShort() -> String {
            let symbols = calendar.shortWeekdaySymbols
            let idx = calendar.component(.weekday, from: day) - 1
            return symbols[idx]
        }

        private func dayNumber() -> String {
            String(calendar.component(.day, from: day))
        }

        var body: some View {
            VStack(spacing: 4) {
                Text(weekdayShort())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(dayNumber())
                    .font(.headline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: isSelected ? 3 : borderWidth)
            )
            .foregroundStyle(textColor)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { onTap() }
        }
    }
    
    struct DayShiftGrid: View {
        @Binding var selections: [[String]]
        let initials: [String]
        let labelFor: (Int, Int) -> String
        let bindingForSelection: (Int, Int) -> Binding<String>
        let isDuplicateInitial: (Int, Int) -> Bool
        
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
                                    .foregroundStyle(.primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)

                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                Text("MLO")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(.primary)
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
                                    .foregroundStyle(.primary)
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
                                    .foregroundStyle(.primary)
                                    .padding(4)
                            }
                            .frame(minWidth: 80, minHeight: 36)

                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("EXE").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("PLN").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("OJTI").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("EXE").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("PLN").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                            ZStack { RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.5), lineWidth: 1); Text("OJTI").font(.subheadline).bold().foregroundStyle(.primary).padding(4) }
                            .frame(minWidth: 80, minHeight: 36)
                        }

                        ForEach(2..<10, id: \.self) { row in
                            GridRow {
                                if row == 8 {
                                    // NOTAM row: merge 2-4, static label in 5, merge 6-7
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text(labelFor(row, 0))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: 36)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 2), options: initials, tintColor: isDuplicateInitial(row, 2) ? .red : nil)
                                    }
                                    .frame(minWidth: 80, minHeight: 36)
                                    .gridCellColumns(3) // columns 2-4

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text("Arı")
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: 36) // column 5

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 6), options: initials, tintColor: isDuplicateInitial(row, 6) ? .red : nil)
                                    }
                                    .frame(minWidth: 80, minHeight: 36)
                                    .gridCellColumns(2) // columns 6-7
                                } else if row == 9 {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text(labelFor(row, 0))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.primary)
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
                                                PickerCell(binding: bindingForSelection(row, col), options: initials, tintColor: isDuplicateInitial(row, col) ? .red : nil)
                                            } else {
                                                let labelText = labelFor(row, col)
                                                Text(labelText)
                                                    .font(.subheadline)
                                                    .bold()
                                                    .foregroundStyle(.primary)
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
                Button(action: { moveTeam(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Text(teams[selectedTeamIndex])
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.blue)
                Spacer()
                Button(action: { moveTeam(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
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

            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(daysInMonth(of: selectedDate).filter { day in
                        return day >= calendar.startOfDay(for: yesterday)
                    }, id: \.self) { day in
                        let red = isRedDay(day)
                        let blue = isBlueDay(day)
                        let todayFlag = calendar.isDateInToday(day)
                        let selectable = red || blue
                        let selectedFlag = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

                        DayPill(
                            day: day,
                            calendar: calendar,
                            isRed: red,
                            isBlue: blue,
                            isToday: todayFlag,
                            isSelected: selectedFlag,
                            onTap: {
                                if selectable { selectedDay = day }
                            }
                        )
                        .opacity(selectable ? 1.0 : 0.4)
                        .allowsHitTesting(selectable)
                    }
                }
                .padding(.horizontal)
            }
            
            DayShiftGrid(
                selections: $selections,
                initials: initials,
                labelFor: { row, col in labelFor(row: row, col: col) },
                bindingForSelection: { row, col in bindingForSelection(row: row, col: col) },
                isDuplicateInitial: { row, col in isDuplicateInitial(at: row, col: col) }
            )
            
        }
        .onAppear {
            let dayCount = daysInMonth(of: selectedDate).count
            ensureMonthMatrixRows(initials: initials, dayCount: dayCount)
            loadMonthMatrix(for: selectedDate)
            let today = calendar.startOfDay(for: Date())
            if let nearest = nearestSelectableDay(in: selectedDate, from: today) {
                selectedDay = nearest
                
                // Load saved selections for the selected day or reset
                if let d = selectedDay {
                    if let loaded = loadDaySelections(for: d) {
                        selections = loaded
                    } else {
                        selections = Array(repeating: Array(repeating: "", count: 7), count: 10)
                    }
                }
            }
        }
        .onChange(of: selectedDate) { _, _ in
            let dayCount = daysInMonth(of: selectedDate).count
            ensureMonthMatrixRows(initials: initials, dayCount: dayCount)
            loadMonthMatrix(for: selectedDate)
        }
        .onChange(of: monthMatrix) { _, _ in
            saveMonthMatrix(for: selectedDate)
        }
        .onChange(of: selectedDay) { _, newDay in
            if let d = newDay {
                if let loaded = loadDaySelections(for: d) {
                    selections = loaded
                } else {
                    selections = Array(repeating: Array(repeating: "", count: 7), count: 10)
                }
            }
        }
        .onChange(of: selections) { _, _ in
            if let d = selectedDay {
                saveDaySelections(for: d)
            }
        }
        .padding()
    }
}

#if canImport(UIKit)
// Removed duplicate ForceLandscapeController, ForceLandscapeModifier, and forceLandscapeIfPossible() here
#endif

// Removed duplicate TakvimWrapperView here

#Preview("Planlama") {
    NavigationStack { PlanlamaView() }
}

#Preview("Takvim") {
    TakvimWrapperView()
}

