//
//  RightClickMenubarApp.swift
//  Right Click Menubar
//
//  All Content Copyright 2025 Zimeng Xiong.
//  All rights reserved.
//  Created by Zimeng Xiong on 6/23/25.
//

import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let rightClick = Self("rightClick", default: .init(.r, modifiers: [.command, .option]))
}

@main
struct RightClickMenubarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
