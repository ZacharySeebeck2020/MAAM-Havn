//
//  AppGroup.swift
//  Havn
//
//  Created by Zac Seebeck on 8/15/25.
//


import Foundation

public enum AppGroup {
    public static let id = "group.work.seebeck.havn"
}

public struct WidgetState: Codable {
    public let hasEntryToday: Bool
    public let streak: Int
    public let bestStreak: Int
    public let locked: Bool
    public let updatedAt: Date
}
