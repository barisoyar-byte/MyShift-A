//
//  Planlama.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI

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

// A simple entry model to represent initials for various roles
struct PlanlamaEntry: Identifiable, Equatable {
    let id = UUID()
    var mloExe: String
    var mloPln: String
    var ojtil: String
    var muwExe: String
    var muwPln: String
    var ojtiu: String
}

struct PlanlamaView: View {
    // Example data to make the view compile and previewable
    @State private var entries: [PlanlamaEntry] = []
    @AppStorage(ekipInitialsKeyPrimary) private var storedInitialsCSVPrimary: String = ""
    @AppStorage(ekipInitialsKeyFallback) private var storedInitialsCSVFallback: String = ""
    @AppStorage(ekipInitialsUserKey) private var storedInitialsUser: String = ""
    
    @State private var teams: [String] = ["A", "B", "C", "D", "E"]
    @State private var selectedTeamIndex: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var selectedDay: Date? = nil
    private let calendar = Calendar.current
    
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
            case 7: return "NOTAM"
            case 8: return "İzin/Mazeret/\nRapor/Görev"
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
    
    struct DayShiftGrid: View {
        @Binding var selections: [[String]]
        let initials: [String]
        let labelFor: (Int, Int) -> String
        let bindingForSelection: (Int, Int) -> Binding<String>
        
        private struct PickerCell: View {
            let binding: Binding<String>
            let options: [String]
            var body: some View {
                Picker("", selection: binding) {
                    ForEach(options, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
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

                        ForEach(2..<9, id: \.self) { row in
                            GridRow {
                                if row == 7 {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text(labelFor(row, 0))
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 8 ? 72 : 36)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 2), options: initials)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 8 ? 72 : 36)
                                    .gridCellColumns(3)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        Text("ARI")
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(.primary)
                                            .padding(4)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 8 ? 72 : 36)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                                        PickerCell(binding: bindingForSelection(row, 6), options: initials)
                                    }
                                    .frame(minWidth: 80, minHeight: row == 8 ? 72 : 36)
                                    .gridCellColumns(2)
                                } else if row == 8 {
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
                                                PickerCell(binding: bindingForSelection(row, col), options: initials)
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
                                        .frame(minWidth: 80, minHeight: row == 8 ? 72 : 36)
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
                        let isRed = isRedDay(day)
                        let isBlue = isBlueDay(day)
                        let isToday = calendar.isDateInToday(day)
                        let isSelectable = isRed || isBlue
                        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                        
                        let textColor: Color = isRed ? .red : (isBlue ? .blue : .primary)
                        let borderColor: Color = isToday ? .blue : (isRed ? .red : (isBlue ? .blue : Color.gray.opacity(0.3)))
                        let borderWidth: CGFloat = isToday ? 2 : 1

                        VStack(spacing: 4) {
                            Text(weekdayShort(for: day))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(dayNumber(for: day))
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
                        .onTapGesture {
                            if isSelectable {
                                selectedDay = day
                            }
                        }
                        .allowsHitTesting(isSelectable)
                    }
                }
                .padding(.horizontal)
            }
            
            DayShiftGrid(
                selections: $selections,
                initials: initials,
                labelFor: { row, col in labelFor(row: row, col: col) },
                bindingForSelection: { row, col in bindingForSelection(row: row, col: col) }
            )
        }
        .padding()
    }
}


#if canImport(UIKit)
import UIKit

private struct ForceLandscapeController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Controller() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            let value = UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }
        override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
        override var shouldAutorotate: Bool { true }
    }
}

private struct ForceLandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ForceLandscapeController().ignoresSafeArea())
    }
}

extension View {
    func forceLandscapeIfPossible() -> some View { self.modifier(ForceLandscapeModifier()) }
}
#endif

// Provide a TakvimView wrapper to satisfy references from Menu.swift
struct TakvimWrapperView: View {
    var body: some View {
        #if canImport(UIKit)
        TakvimGestureView()
            .forceLandscapeIfPossible()
        #else
        TakvimGestureView()
        #endif
    }
}

#Preview("Planlama") {
    NavigationStack { PlanlamaView() }
}

#Preview("Takvim") {
    TakvimWrapperView()
}

