//
//  ChipPickerSheet.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI

struct ChipPickerSheet: View {
    @Binding var tags: [String]
    var knownTags: [String]? = nil
    @State private var newTagText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage Tags").font(.headline).padding(.horizontal).padding(.vertical)

            // Input
            HStack(spacing: 8) {
                Image(systemName: "tag").imageScale(.small)
                TextField("Search or add a tag…", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addNewTag)
                Button("Add") { addNewTag() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            // Suggestions
            if let known = knownTags {
                let filtered = known.filter { q in
                    newTagText.isEmpty || q.localizedCaseInsensitiveContains(newTagText)
                }.filter { k in
                    !tags.contains(where: { $0.caseInsensitiveCompare(k) == .orderedSame })
                }
                if !filtered.isEmpty {
                    Text("Suggestions").font(.caption).padding(.horizontal)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(filtered, id: \.self) { k in
                            Button { tags.append(k) } label: {
                                HStack(spacing: 6) {
                                    Text(k).font(.callout.weight(.semibold))
                                    Image(systemName: "plus.circle.fill").imageScale(.small)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Selected tags
            FlowTags(tags: tags) { tag in
                tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
            }

            Spacer(minLength: 0)
        }
    }

    private func addNewTag() {
        let t = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let norm = t
        if !tags.contains(where: { $0.caseInsensitiveCompare(norm) == .orderedSame }) {
            tags.append(norm)
        }
        newTagText = ""
    }
}