//
//  ChipKind.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI
import PhotosUI

enum ChipKind: String, Identifiable {
    case mood, energy, weather, tags
    var id: String { rawValue }
}

struct PillChip: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).imageScale(.small) }
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityLabel(title)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.accentColor.opacity(0.7)))
            .contentShape(Capsule())
        }
        .buttonStyle(Pressable())
    }
}

struct MetaChipsRow: View {
    @Binding var photoSelection: PhotosPickerItem?
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

                Button { showPhotoPicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill").imageScale(.small)
                        Text("Set Today’s Image")
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor.opacity(0.7)))
                    .foregroundStyle(.primary)
                    .contentShape(Capsule())
                }
                .buttonStyle(Pressable())
                .simultaneousGesture(TapGesture().onEnded { UIImpactFeedbackGenerator(style: .soft).impactOccurred() })
                .photosPicker(isPresented: $showPhotoPicker, selection: $photoSelection, matching: .images)
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