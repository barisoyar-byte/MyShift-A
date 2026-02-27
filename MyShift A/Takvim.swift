//
//  Takvim.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI

private struct IdentifiedValue<T>: Identifiable {
    let id: String
    let value: T
}

struct TakvimGestureView: View {
    private let calendar = Calendar.current
//    private let dayCellWidth: CGFloat = 36
    @State private var selectedDate: Date = Date()
    
    private let teams: [String] = ["A", "B", "C", "D", "E"]
    @AppStorage("selectedTeamIndex") private var selectedTeamIndex: Int = 0

    // Load initials written by EkipView via UserDefaults as CSV
    @AppStorage("userInitials") private var userInitialsCSV: String = ""
    private var initials: [String] {
        userInitialsCSV
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private let cellOptions: [String] = [
        "Ücretli İzin","Geçici Görevli","Mazeret","Saatlik Mazeret","Rapor","Normal Mesai","Ekip Değişikliği","Yurt dışı Geçici Görev","Refakat İzni","Süt İzni","İdari İzinli","Hastane","Ölüm İzni"
    ]
    private let optionAbbreviations: [String: String] = [
        "Ücretli İzin": "Üİ",
        "Geçici Görevli": "GG",
        "Mazeret": "MZ",
        "Saatlik Mazeret": "SM",
        "Rapor": "RP",
        "Normal Mesai": "NM",
        "Ekip Değişikliği": "ED",
        "Yurt dışı Geçici Görev": "YG",
        "Refakat İzni": "Rİ",
        "Süt İzni": "Sİ",
        "İdari İzinli": "İİ",
        "Hastane": "HS",
        "Ölüm İzni": "Öİ"
    ]
    private let optionColors: [String: Color] = [
        "Ücretli İzin": .orange,
        "Geçici Görevli": .purple,
        "Mazeret": .pink,
        "Saatlik Mazeret": .teal,
        "Rapor": .red,
        "Normal Mesai": .green,
        "Ekip Değişikliği": .blue,
        "Yurt dışı Geçici Görev": .indigo,
        "Refakat İzni": .brown,
        "Süt İzni": .mint,
        "İdari İzinli": .cyan,
        "Hastane": .gray,
        "Ölüm İzni": .black
    ]

    // Keyed by (dayIndex, rowIndex) to persist per-cell selection
    @State private var cellSelections: [String: String] = [:]

    // Custom selection UI state
    @State private var presentingCellKey: String? = nil

    // Drag selection state for the top blank row
    @State private var dragSelecting = false
    @State private var dragStartDayIndex: Int? = nil
    @State private var dragCurrentDayIndex: Int? = nil
    @State private var mergedRanges: [ClosedRange<Int>] = []
    
    // Merged block text storage and editing state
    @State private var mergedTexts: [ClosedRange<Int>: String] = [:]
    @State private var editingRange: ClosedRange<Int>? = nil

    private func cellKey(dayIndex: Int, rowIndex: Int) -> String { "\(dayIndex)-\(rowIndex)" }
    
    private func isDay(_ dayIndex: Int, in range: ClosedRange<Int>) -> Bool { range.contains(dayIndex) }
    private func isDayInAnyMergedRange(_ dayIndex: Int) -> Bool { mergedRanges.contains(where: { $0.contains(dayIndex) }) }
    
    private func mergedRange(containing dayIndex: Int) -> ClosedRange<Int>? {
        mergedRanges.first(where: { $0.contains(dayIndex) })
    }
    private func isStart(of range: ClosedRange<Int>, at dayIndex: Int) -> Bool { range.lowerBound == dayIndex }

    @ViewBuilder
    private func selectionSheet(for key: String) -> some View {
        NavigationStack {
            List {
                Section("Seçenekler") {
                    ForEach(cellOptions, id: \.self) { option in
                        Button(action: {
                            cellSelections[key] = option
                            presentingCellKey = nil
                        }) {
                            HStack {
                                let abbr = optionAbbreviations[option] ?? ""
                                HStack(spacing: 6) {
                                    if !abbr.isEmpty {
                                        Text(abbr)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(optionColors[option] ?? .secondary)
                                    }
                                    Text(option)
                                        .font(.headline.weight(.medium))
                                }
                                Spacer()
                                if cellSelections[key] == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                if cellSelections[key] != nil && cellSelections[key] != "" {
                    Section {
                        Button(role: .destructive) {
                            cellSelections[key] = ""
                            presentingCellKey = nil
                        } label: {
                            Text("Temizle")
                        }
                    }
                }
            }
            .navigationTitle("Seçim Yap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { presentingCellKey = nil } } }
        }
    }

    private var dateRange: ClosedRange<Date> {
        let startComps = DateComponents(year: 2026, month: 1, day: 1)
        let start = calendar.date(from: startComps) ?? Date()
        let today = Date()
        // End should be at least today, or up to 5 years after start, whichever is later
        let fiveYearsAfterStart = calendar.date(byAdding: .year, value: 5, to: start) ?? today
        let end = max(today, fiveYearsAfterStart)
        return start...end
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

            // Days header strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Left fixed labels column
                    VStack(alignment: .leading, spacing: 4) {
                        // Header spacer to align with day header (weekday + day number)
                        VStack(spacing: 4) {
                            Text("")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(width: 80, alignment: .leading)
                        .padding(.vertical, 8)
                        
                        // Frameless blank row above initials (first column only)
                        Color.clear
                            .frame(width: 80, height: 28)

                        // Initials rows
                        ForEach(initials, id: \.self) { ini in
                            Text(ini)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: 80, alignment: .leading)
                                .frame(height: 28)
                        }
                        // Var and Yok rows
                        Text("Var")
                            .font(.callout.weight(.semibold))
                            .frame(width: 80, alignment: .leading)
                            .frame(height: 28)
                        Text("Yok")
                            .font(.callout.weight(.semibold))
                            .frame(width: 80, alignment: .leading)
                            .frame(height: 28)
                    }

                    // Day columns (no initials here)
                    ForEach(daysInMonth(of: selectedDate), id: \.self) { day in
                        let isRed = isRedDay(day)
                        let isBlue = isBlueDay(day)
                        let isToday = calendar.isDateInToday(day)

                        let textColor: Color = isRed ? .red : (isBlue ? .blue : .primary)
                        let borderColor: Color = isToday ? .blue : (isRed ? .red : (isBlue ? .blue : Color.gray.opacity(0.3)))
                        let borderWidth: CGFloat = isToday ? 2 : 1

                        VStack(spacing: 4) {
                            // Day header
                            Text(weekdayShort(for: day))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(dayNumber(for: day))
                                .font(.title3.weight(.semibold))
                            
                            // Blank framed row to align with left blank row (supports drag selection and merged block)
                            let topRowDayIndex = calendar.component(.day, from: day)
                            let isInDraggingRange: Bool = {
                                if let s = dragStartDayIndex, let c = dragCurrentDayIndex, dragSelecting {
                                    let lower = min(s, c)
                                    let upper = max(s, c)
                                    return (lower...upper).contains(topRowDayIndex)
                                }
                                return false
                            }()
                            let activeMerged = mergedRange(containing: topRowDayIndex)
                            let isMerged = activeMerged != nil
                            let isMergedStart = isMerged && isStart(of: activeMerged!, at: topRowDayIndex)

                            ZStack {
                                if let range = activeMerged, isMergedStart {
                                    // Render a merged block starting at this day, spanning the whole range width via overlay
                                    let span = range.count // number of days in range
                                    let cellWidth: CGFloat = 60
                                    let blockWidth = CGFloat(span) * cellWidth
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .frame(width: blockWidth, height: 28, alignment: .leading)
                                        .alignmentGuide(.leading) { d in d[.leading] }
                                        .onTapGesture {
                                            editingRange = range
                                        }
                                        .overlay(
                                            Text(mergedTexts[range] ?? "")
                                                .font(.footnote.weight(.semibold))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                                .padding(.horizontal, 4)
                                                .frame(width: blockWidth - 8, alignment: .center)
                                        , alignment: .center)
                                } else {
                                    // Regular single cell background (drag feedback or idle)
                                    let bg = isInDraggingRange ? Color.indigo.opacity(0.25) : (isMerged ? Color.clear : Color.clear)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(bg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .frame(width: 60, height: 28)
                                }
                            }
                            .frame(width: 60, height: 28)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if isMerged { return }
                                        if dragStartDayIndex == nil {
                                            dragStartDayIndex = topRowDayIndex
                                        }
                                        dragCurrentDayIndex = topRowDayIndex
                                        dragSelecting = true
                                    }
                                    .onEnded { _ in
                                        if isMerged { return }
                                        dragSelecting = false
                                        if let s = dragStartDayIndex, let c = dragCurrentDayIndex {
                                            let lower = min(s, c)
                                            let upper = max(s, c)
                                            mergedRanges.append(lower...upper)
                                        }
                                        dragStartDayIndex = nil
                                        dragCurrentDayIndex = nil
                                    }
                            )

                            // Interactive rows aligned with left labels (only initials rows + Var/Yok)
                            ForEach(0..<(initials.count + 2), id: \.self) { r in
                                let dayIndex = calendar.component(.day, from: day)
                                let key = cellKey(dayIndex: dayIndex, rowIndex: r)

                                // Compute counts once per column
                                let filledCount: Int = {
                                    var c = 0
                                    for i in 0..<initials.count {
                                        let k = cellKey(dayIndex: dayIndex, rowIndex: i)
                                        if let v = cellSelections[k], !v.isEmpty { c += 1 }
                                    }
                                    return c
                                }()
                                let emptyCount = max(0, initials.count - filledCount)
                                let yokCount = filledCount
                                let varCount = emptyCount

                                if r < initials.count {
                                    Button {
                                        presentingCellKey = key
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.clear))
                                            let full = cellSelections[key] ?? ""
                                            let abbrev = optionAbbreviations[full] ?? ""
                                            let color = optionColors[full] ?? .primary
                                            Text(abbrev)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(color)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                                .padding(.horizontal, 2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 60, height: 28)
                                } else if r == initials.count {
                                    // Var count row with 1-5 red-toned background
                                    let varTone: Color = {
                                        switch varCount {
                                        case 1: return .yellow
                                        case 2: return .orange
                                        case 3: return .orange.opacity(0.8)
                                        case 4: return .red.opacity(0.8)
                                        case 5: return .red
                                        default: return .clear
                                        }
                                    }()
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(varTone == .clear ? Color.clear : varTone.opacity(0.25))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        Text("\(varCount)")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle((1...5).contains(varCount) ? Color.white : Color.black)
                                    }
                                    .frame(width: 60, height: 28)
                                } else {
                                    // Yok count row with 1-5 red-toned background
                                    let yokTone: Color = {
                                        switch yokCount {
                                        case 1: return .yellow
                                        case 2: return .orange
                                        case 3: return .orange.opacity(0.8)
                                        case 4: return .red.opacity(0.8)
                                        case 5: return .red
                                        default: return .clear
                                        }
                                    }()
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(yokTone == .clear ? Color.clear : yokTone.opacity(0.25))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                        Text("\(yokCount)")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle((1...5).contains(yokCount) ? Color.white : Color.black)
                                    }
                                    .frame(width: 60, height: 28)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isToday ? Color.yellow.opacity(0.25) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: borderWidth)
                        )
                        .foregroundStyle(textColor)
                    }
                }
                .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    
                    ForEach(cellOptions, id: \.self) { option in
                        let abbr = optionAbbreviations[option] ?? ""
                        if !abbr.isEmpty {
                            HStack(spacing: 4) {
                                Text(abbr)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(optionColors[option] ?? .primary)
                                Text(option)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)
            .sheet(item: Binding(
                get: {
                    presentingCellKey.map { IdentifiedValue(id: $0, value: $0) }
                },
                set: { newValue in
                    presentingCellKey = newValue?.value
                }
            )) { identified in
                selectionSheet(for: identified.value)
            }
            .sheet(isPresented: Binding(
                get: { editingRange != nil },
                set: { if !$0 { editingRange = nil } }
            )) {
                if let range = editingRange {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Birleştirilmiş Hücre Metni")
                                .font(.headline)
                            TextField("Metin girin", text: Binding(
                                get: { mergedTexts[range] ?? "" },
                                set: { mergedTexts[range] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            Spacer()
                        }
                        .padding()
                        .navigationTitle("Metin Düzenle")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { editingRange = nil } } }
                    }
                }
            }
        }
        .padding()
    }
    
    private func moveTeam(by offset: Int) {
        let count = teams.count
        guard count > 0 else { return }
        let normalizedOffset = ((offset % count) + count) % count
        let newIndex = (selectedTeamIndex + normalizedOffset) % count
        selectedTeamIndex = newIndex
    }
    
    private func changeMonth(by offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: selectedDate) {
            // Clamp to dateRange if needed
            if newDate < dateRange.lowerBound {
                selectedDate = dateRange.lowerBound
            } else if newDate > dateRange.upperBound {
                selectedDate = dateRange.upperBound
            } else {
                selectedDate = newDate
            }
        }
    }

    private func daysInMonth(of date: Date) -> [Date] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }
        return monthRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
        }
    }

    private func monthYearString(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        let comp = calendar.component(.day, from: date)
        return String(comp)
    }

    private func weekdayShort(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "EE" // short weekday
        return df.string(from: date)
    }
    
    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
    
    private func teamDayOffset() -> Int {
        switch teams[selectedTeamIndex] {
        case "B": return 1
        case "C": return 2
        case "D": return 3
        case "E": return 4
        default: return 0 // A
        }
    }
    
    private func isRedDay(_ date: Date) -> Bool {
        let comps = DateComponents(year: 2026, month: 1, day: 5)
        guard let start = calendar.date(from: comps) else { return false }
        // Only on/after start
        guard date >= start else { return false }
        let offset = teamDayOffset()
        let adjustedStart = calendar.date(byAdding: .day, value: offset, to: startOfDay(start)) ?? startOfDay(start)
        let days = calendar.dateComponents([.day], from: adjustedStart, to: startOfDay(date)).day ?? -1
        return days % 5 == 0
    }

    private func isBlueDay(_ date: Date) -> Bool {
        let comps = DateComponents(year: 2026, month: 1, day: 1)
        guard let start = calendar.date(from: comps) else { return false }
        // Only on/after start
        guard date >= start else { return false }
        let offset = teamDayOffset()
        let adjustedStart = calendar.date(byAdding: .day, value: offset, to: startOfDay(start)) ?? startOfDay(start)
        let days = calendar.dateComponents([.day], from: adjustedStart, to: startOfDay(date)).day ?? -1
        return days % 5 == 0
    }
}

#if canImport(UIKit)
import UIKit

private struct ForceLandscapeController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Attempt to set device orientation to landscape
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
        content
            .background(ForceLandscapeController().ignoresSafeArea())
    }
}

private extension View {
    func msa_forceLandscapeIfPossible() -> some View { self.modifier(ForceLandscapeModifier()) }
}
#endif

// Keep PlanlamaView as a separate top-level view
struct PlanlamaScreen: View {
    @AppStorage("Menu") private var menu = false
    @State private var navigateToMenu = false

    var body: some View {
        VStack {
            Text("Gündüz")
                .font(.largeTitle.bold())
                .padding()
        }
        .navigationTitle("Planlama")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Provide a TakvimView wrapper to satisfy references from Menu.swift
struct TakvimView: View {
    var body: some View {
        #if canImport(UIKit)
        TakvimGestureView()
            .msa_forceLandscapeIfPossible()
        #else
        TakvimGestureView()
        #endif
    }
}

#Preview {
    TakvimView()
}

