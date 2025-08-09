//
//  Day.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import Foundation

enum Day {
    static func start(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
    static func next(_ d: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: start(d))!
    }
}
