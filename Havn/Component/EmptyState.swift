//
//  EmptyState.swift
//  Havn
//
//  Created by Zac Seebeck on 8/12/25.
//

import SwiftUI

struct EmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage).font(.largeTitle)
                .foregroundStyle(Color("TextMutedColor"))
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline)
                .foregroundStyle(Color("TextMutedColor"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
