//
//  JournalView.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import SwiftUI

struct JournalView: View {
    @State private var selectedDay = Day.start(Date())

    var body: some View {
        VStack(spacing: 12) {
            WeekStrip(selectedDay: $selectedDay)
            EntryEditor(day: selectedDay)
            Spacer(minLength: 0)
        }
        .tint(Color("AccentColor"))
    }
}

#Preview("Interactive • Light") {
    JournalView()
}

#Preview("Interactive • Dark") {
    JournalView()
        .preferredColorScheme(ColorScheme.dark)
}
