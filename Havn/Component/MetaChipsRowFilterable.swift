//
//  ChipKind.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI
import PhotosUI

struct MetaChipsRowFilterable: View {
    @Binding var moodScore: Double
    @Binding var energyScore: Double
    @Binding var weatherScore: Double
    @Binding var tags: [String]
    let knownTags: [String]
    @State private var showPickerFor: ChipKind? = nil
    @State private var showPhotoPicker: Bool = false

    var body: some View {
        VStack {
            HStack(spacing: 3) {
                PillChip(title: "Mood: " + emoji(for: moodScore, kind: .mood), icon: nil, isActive: moodScore != 3) { showPickerFor = .mood }
                PillChip(title: "Energy: " + emoji(for: energyScore, kind: .energy), icon: nil, isActive: energyScore != 3) { showPickerFor = .energy }
                PillChip(title: "Weather: " + emoji(for: weatherScore, kind: .weather), icon: nil, isActive: weatherScore != 3) { showPickerFor = .weather }
            }
            HStack(spacing: 8) {
                PillChip(title: "Tags", icon: "tag.fill", isActive: !tags.isEmpty) { showPickerFor = .tags }
            }
            .padding(.bottom, 6)
        }
        .sheet(item: $showPickerFor) { kind in
            switch kind {
            case .mood:
                EmojiGridPicker(kind: .mood, value: $moodScore)
                    .presentationDetents([.height(240)])
                    .presentationDragIndicator(.hidden)
            case .energy:
                EmojiGridPicker(kind: .energy, value: $energyScore)
                    .presentationDetents([.height(240)])
                    .presentationDragIndicator(.hidden)
            case .weather:
                EmojiGridPicker(kind: .weather, value: $weatherScore)
                    .presentationDetents([.height(240)])
                    .presentationDragIndicator(.hidden)
            case .tags:
                ChipPickerSheet(tags: $tags, knownTags: knownTags)
                    .presentationDetents([.height(360), .medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func emoji(for value: Double, kind: ChipKind) -> String {
        let idx = max(1, min(5, Int(value.rounded()))) - 1
        let arr = VitalsEmoji.emojis(for: kind)
        guard arr.indices.contains(idx) else { return "" }
        return arr[idx]
    }
}
