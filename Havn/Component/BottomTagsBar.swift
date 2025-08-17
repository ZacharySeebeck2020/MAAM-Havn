//
//  BottomTagsBar.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI

struct BottomTagsBar: View {
    @Binding var tags: [String]

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill").imageScale(.small)
                            Text(tag).font(.callout.weight(.semibold))
                            Button {
                                tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                            } label: {
                                Image(systemName: "xmark.circle.fill").imageScale(.small)
                            }
                            .accessibilityLabel("Remove tag \(tag)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct FlowTags: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 6) {
                    Text(tag).font(.callout.weight(.semibold))
                    Button(role: .destructive) {
                        onRemove(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill").imageScale(.small)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                .overlay(Capsule().stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal)
    }
}