//
//  TutorialOverlay.swift
//  Havn
//
//  Created by Zac Seebeck on 8/17/25.
//

import SwiftUI

struct TutorialOverlay: View {
    let step: TutorialStep
    let nextAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack {
                Spacer()

                switch step {
                case .setImage:
                    Text("Tap here to set today’s image.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)

                case .addMood:
                    Text("Pick your mood, energy, and weather here.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)

                case .writeEntry:
                    Text("Write your daily entry in this space.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)

                case .viewStreaks:
                    Text("Track your progress with streaks here.")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Spacer()
                Button("Next", action: nextAction)
                    .padding()
                Button("Skip Tutorial", action: skipAction)
                    .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: step)
    }
}
