//
//  VitalsEmoji.swift
//  Havn
//
//  Created by Zac Seebeck on 8/16/25.
//


import SwiftUI

enum VitalsEmoji {
    static func emojis(for kind: ChipKind) -> [String] {
        switch kind {
        case .mood:    return ["😞","😌","😐","🙂","😄"]
        case .energy:  return ["🥱","😴","🙂","⚡️","🚀"]
        case .weather: return ["🌧️","☁️","🌤️","☀️","🌈"]
        case .tags:    return []
        }
    }
}