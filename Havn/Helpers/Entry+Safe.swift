//
//  Entry+Safe.swift
//  Havn
//
//  Created by Zac Seebeck on 8/9/25.
//

import Foundation

extension JournalEntry {
    var dayValue: Date { day ?? Calendar.current.startOfDay(for: Date()) }
    var textValue: String { text ?? "" }
}
