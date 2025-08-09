//
//  WeekStrip.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

struct WeekStrip: View {
    @Binding var selectedDay: Date

    private var days: [Date] {
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { d in
                let sel = Calendar.current.isDate(d, inSameDayAs: selectedDay)
                Button {
                    selectedDay = Day.start(d)
                } label: {
                    VStack(spacing: 2) {
                        Text(d.formatted(.dateTime.weekday(.narrow))).font(.caption2)
                        Text(d.formatted(.dateTime.day())).font(.body).bold()
                    }
                    .frame(width: 44, height: 48)
                    .padding(.vertical, 6)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sel ? Color("AccentColor").opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(sel ? Color("AccentColor").opacity(0.35) : Color("AccentColor").opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
}

private struct WeekStripPreviewHarness: View {
    @State var selectedDay = Day.start(Date())
    var body: some View {
        WeekStrip(selectedDay: $selectedDay)
            .padding()
            .tint(Color("AccentColor"))
            .background(Color("BackgroundColor"))
    }
}

#Preview("Interactive • Light") { WeekStripPreviewHarness() }
#Preview("Interactive • Dark")  {
    WeekStripPreviewHarness()
        .preferredColorScheme(.dark)
}
