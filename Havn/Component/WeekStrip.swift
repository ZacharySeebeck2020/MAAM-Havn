//
//  WeekStrip.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

struct WeekStrip: View {
    @Binding var selectedDay: Date
    @Environment(\.colorScheme) private var scheme
    @State private var weekStart: Date = Calendar.current.startOfWeek(containing: Date())
    
    private var selFillOpacity: Double   { scheme == .dark ? 0.36 : 0.24 }
    private var selStrokeOpacity: Double { scheme == .dark ? 0.55 : 0.40 }
    private var weekdayOpacity: Double   { scheme == .dark ? 0.85 : 0.65 }

    private var days: [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { d in
                let sel = Calendar.current.isDate(d, inSameDayAs: selectedDay)
                let dStart = Calendar.current.startOfDay(for: d)
                let today = Calendar.current.startOfDay(for: Date())
                Button {
                    selectedDay = min(today, dStart)
                } label: {
                    VStack(spacing: 2) {
                        Text(d.formatted(.dateTime.weekday(.narrow)))
                            .font(HavnTheme.Typeface.weekday)
                            .foregroundStyle(
                                sel ? Color.black :
                                Color("TextMainColor").opacity(sel ? 1 : weekdayOpacity)
                            )
                        Text(d.formatted(.dateTime.day()))
                            .font(HavnTheme.Typeface.dayNumber).bold()
                            .foregroundStyle(
                                sel ? Color.black :
                                Color("TextMainColor").opacity(sel ? 1 : weekdayOpacity)
                            )
                    }
                    .frame(width: 44, height: 48)
                    .padding(.vertical, 6)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sel ? Color("CallToActionColor").opacity(selFillOpacity) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(sel ? Color("AccentColor").opacity(selStrokeOpacity) : Color.clear )
                )
                .accessibilityLabel(
                    Text(d, format: .dateTime.weekday(.wide).month().day().year())
                )
                .accessibilityValue(sel ? "Selected" : "")
            }
        }
        .padding(.horizontal)
        // Keep the strip anchored to the week that contains `selectedDay`
        .onAppear {
            weekStart = Calendar.current.startOfWeek(containing: selectedDay)
        }
        .onChange(of: selectedDay) { _, new in
            // shift only when crossing into a different week
            let cal = Calendar.current
            if !cal.isDate(new, equalTo: weekStart, toGranularity: .weekOfYear) {
                withAnimation(.snappy) {
                    weekStart = cal.startOfWeek(containing: new)
                }
            }
        }
    }
}

// MARK: - Helpers

private extension Calendar {
    func startOfWeek(containing d: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return self.date(from: comps)!
    }
}

private struct WeekStripPreviewHarness: View {
    @State var selectedDay = Day.start(Date())
    var body: some View {
        WeekStrip(selectedDay: $selectedDay)
            .padding()
            .background(Color("PrimaryColor"))
    }
}

#Preview("Interactive • Light") { WeekStripPreviewHarness() }
#Preview("Interactive • Dark")  {
    WeekStripPreviewHarness()
        .preferredColorScheme(.dark)
}
