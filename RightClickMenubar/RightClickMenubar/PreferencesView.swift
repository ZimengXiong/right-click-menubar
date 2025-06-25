//
//  PreferencesView.swift
//  Right Click Menubar
//
//  All Content Copyright 2025 Zimeng Xiong.
//  All rights reserved.
//  Created by Zimeng Xiong on 6/23/25.
//

import SwiftUI
import KeyboardShortcuts

enum TriggerMode: String, CaseIterable, Identifiable {
    case keyboardShortcut = "Keyboard Shortcut"
    case clickModifier = "Click Modifier"
    var id: Self { self }
}

struct PreferencesView: View {
    @AppStorage("triggerMode") private var triggerMode: TriggerMode = .keyboardShortcut
    @AppStorage("selectedModifiers") private var selectedModifiers: Int = Int(NSEvent.ModifierFlags.command.rawValue)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
        
            if #available(macOS 14.0, *) {
                Picker("Trigger Method", selection: $triggerMode) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .onChange(of: triggerMode) {
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            } else {
                // Fallback on earlier versions
            }

            Divider()

            if triggerMode == .keyboardShortcut {
                keyboardShortcutView
            } else {
                clickModifierView
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 450, height: 350)
    }

    private var keyboardShortcutView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Keyboard Shortcut")
                .font(.title2)
            Text("Set a global keyboard shortcut to trigger the application menu. The default is Command+Option+R.")
                .foregroundColor(.gray)
            
            KeyboardShortcuts.Recorder(for: .rightClick)
        }
    }

    private var clickModifierView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Click Modifier")
                .font(.title2)
            Text("Hold down one or more modifier keys and right-click to trigger the menu. The default is Command.")
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                ModifierCheckbox(title: "Command (⌘)", modifier: .command, selectedModifiers: $selectedModifiers)
                ModifierCheckbox(title: "Option (⌥)", modifier: .option, selectedModifiers: $selectedModifiers)
                ModifierCheckbox(title: "Control (⌃)", modifier: .control, selectedModifiers: $selectedModifiers)
                ModifierCheckbox(title: "Shift (⇧)", modifier: .shift, selectedModifiers: $selectedModifiers)
            }
        }
    }
}

struct ModifierCheckbox: View {
    let title: String
    let modifier: NSEvent.ModifierFlags
    @Binding var selectedModifiers: Int

    var body: some View {
        let modifierIntValue = Int(modifier.rawValue)
        
        Toggle(isOn: Binding(
            get: { (selectedModifiers & modifierIntValue) != 0 },
            set: { isOn in
                if isOn {
                    selectedModifiers |= modifierIntValue
                } else {
                    selectedModifiers &= ~modifierIntValue
                }
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
            }
        )) {
            Text(title)
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

#Preview{
    PreferencesView()
}
