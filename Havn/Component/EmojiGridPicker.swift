//
//  EmojiGridPicker.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI

struct EmojiGridPicker: View {
    let kind: ChipKind
    @Binding var value: Double
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch kind {
        case .mood: "How are you feeling?"
        case .energy: "Energy level"
        case .weather: "Today’s weather"
        case .tags: ""
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.top, 12)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 8) {
                ForEach(Array(VitalsEmoji.emojis(for: kind).enumerated()), id: \.offset) { idx, e in
                    let selected = (idx == Int(value.rounded()) - 1)
                    Text(e)
                        .font(selected ? .system(size: 40) : .system(size: 34))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Circle().fill(Color.accentColor.opacity(selected ? 0.22 : 0)))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                value = Double(idx + 1)
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                dismiss()
                            }
                        }
                        .accessibilityLabel("\(title) option \(idx + 1)")
                }
            }
            .padding(.horizontal, 18)

            Button("Cancel") { dismiss() }
                .font(.callout)
                .padding(.top, 4)
        }
        .padding(.bottom, 12)
    }
}