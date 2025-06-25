//
//  ContentView.swift
//  Right Click Menubar
//
//  All Content Copyright 2025 Zimeng Xiong.
//  All rights reserved.
//  Created by Zimeng Xiong on 6/23/25.
//
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Preferences...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
    }
}
