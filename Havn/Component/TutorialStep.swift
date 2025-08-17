//
//  TutorialStep.swift
//  Havn
//
//  Created by Zac Seebeck on 8/17/25.
//

import SwiftUI


enum TutorialStep: Int, CaseIterable {
    case setImage, addMood, writeEntry, viewStreaks
}

class TutorialManager: ObservableObject {
    @Published var currentStep: TutorialStep? = .setImage

    func nextStep() {
        if let step = currentStep,
           let index = TutorialStep.allCases.firstIndex(of: step),
           index + 1 < TutorialStep.allCases.count {
            currentStep = TutorialStep.allCases[index + 1]
        } else {
            currentStep = nil // Tutorial finished
        }
    }

    func skip() {
        currentStep = nil
    }
}
