//
//  Takvim.swift
//  MyShift A
//
//  Created by Barış Oyar on 23.02.2026.
//

import SwiftUI

struct TakvimGestureView: View {
    private let calendar = Calendar.current
    @State private var selectedDate: Date = Date()
    
    private let teams: [String] = ["A Ekibi", "B Ekibi", "C Ekibi", "D Ekibi", "E Ekibi"]
    @State private var selectedTeamIndex: Int = 0

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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(daysInMonth(of: selectedDate), id: \.self) { day in
                        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                        let isRed = isRedDay(day)
                        let isBlue = isBlueDay(day)
                        let isToday = calendar.isDateInToday(day)

                        // Priority: Selected > Today ring > Red/Blue coloring
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
                                .fill(isToday ? Color.yellow.opacity(0.25) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: borderWidth)
                        )
                        .foregroundStyle(textColor)
                        .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)
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
        case "B Ekibi": return 1
        case "C Ekibi": return 2
        case "D Ekibi": return 3
        case "E Ekibi": return 4
        default: return 0 // A Ekibi
        }
    }
    
    private func isRedDay(_ date: Date) -> Bool {
        var comps = DateComponents(year: 2026, month: 1, day: 5)
        guard let start = calendar.date(from: comps) else { return false }
        // Only on/after start
        guard date >= start else { return false }
        let offset = teamDayOffset()
        let adjustedStart = calendar.date(byAdding: .day, value: offset, to: startOfDay(start)) ?? startOfDay(start)
        let days = calendar.dateComponents([.day], from: adjustedStart, to: startOfDay(date)).day ?? -1
        return days % 5 == 0
    }

    private func isBlueDay(_ date: Date) -> Bool {
        var comps = DateComponents(year: 2026, month: 1, day: 1)
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
            UIViewController.attemptRotationToDeviceOrientation()
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
    func forceLandscapeIfPossible() -> some View { self.modifier(ForceLandscapeModifier()) }
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
            .forceLandscapeIfPossible()
        #else
        TakvimGestureView()
        #endif
    }
}

#Preview {
    TakvimView()
}
