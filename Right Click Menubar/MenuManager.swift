//
//  MenuManager.swift
//  Right Click Menubar
//
//  Created by Zimeng Xiong on 6/23/25.
//

import AppKit
import SwiftUI
import KeyboardShortcuts

let kAXMenuItemSubmenuAttribute = "AXMenuItemSubmenu"
let kAXMenuItemCmdCharAttribute = "AXMenuItemCmdChar"
let kAXMenuItemCmdModifiersAttribute = "AXMenuItemCmdModifiers"

class MenuManager: NSObject, NSMenuDelegate, NSMenuItemValidation {
    private var eventTap: CFMachPort? = nil
    private var runLoopSource: CFRunLoopSource? = nil
    private var triggerMode: TriggerMode = .keyboardShortcut
    private var selectedModifiers: NSEvent.ModifierFlags = [.command]

    override init() {
        super.init()
        loadSettings()
        setupEventMonitoring()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .settingsChanged, object: nil)
    }
    
    deinit {
        stopEventMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadSettings() {
        let modeRaw = UserDefaults.standard.string(forKey: "triggerMode") ?? TriggerMode.keyboardShortcut.rawValue
        triggerMode = TriggerMode(rawValue: modeRaw) ?? .keyboardShortcut
        let modifiersInt = UserDefaults.standard.integer(forKey: "selectedModifiers")
        selectedModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiersInt))
    }
    
    @objc private func settingsChanged() {
        loadSettings()
        stopEventMonitoring()
        setupEventMonitoring()
    }
    
    private func setupEventMonitoring() {
        switch triggerMode {
        case .keyboardShortcut:
            setupKeyboardEventTap()
        case .clickModifier:
            setupMouseEventTap()
        }
    }
    
    private func stopEventMonitoring() {
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }
    
    private func setupKeyboardEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard type == .keyDown else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<MenuManager>.fromOpaque(refcon!).takeUnretainedValue()
                if manager.isTriggeringKeyEvent(event) {
                    DispatchQueue.main.async {
                        manager.handleTrigger()
                    }
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        if let eventTap = eventTap {
            self.eventTap = eventTap
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }
    
    private func isTriggeringKeyEvent(_ event: CGEvent) -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .rightClick), let key = shortcut.key else { return false }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let eventFlags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).intersection(.deviceIndependentFlagsMask)
        let eventFlagsInt = Int(eventFlags.rawValue)
        let shortcutFlagsInt = Int(shortcut.modifiers.rawValue)
        return keyCode == key.rawValue && eventFlagsInt == shortcutFlagsInt
    }
    
    private func setupMouseEventTap() {
        let eventMask = (1 << CGEventType.rightMouseDown.rawValue)
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard type == .rightMouseDown else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<MenuManager>.fromOpaque(refcon!).takeUnretainedValue()
                if manager.isTriggeringMouseEvent(event) {
                    DispatchQueue.main.async {
                        manager.handleTrigger()
                    }
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        if let eventTap = eventTap {
            self.eventTap = eventTap
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            self.runLoopSource = runLoopSource
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func isTriggeringMouseEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let nsFlags = NSEvent.ModifierFlags(rawValue: UInt(flags.rawValue))
        let eventFlags = nsFlags.intersection(.deviceIndependentFlagsMask)
        return eventFlags == self.selectedModifiers
    }
    
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "This app needs Accessibility permission to read and interact with other apps' menu bars. Please enable it in System Settings > Privacy & Security > Accessibility."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    private struct MenuNode {
        let title: String
        let role: String
        let element: AXUIElement
        let children: [MenuNode]
        let enabled: Bool
        let keyEquivalent: String
        let keyEquivalentModifierMask: NSEvent.ModifierFlags
    }

    private func fetchFrontmostAppMenuBar() -> [MenuNode]? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("[DEBUG] No frontmost application found.")
            return nil
        }
        let pid = frontApp.processIdentifier
        print("[DEBUG] Frontmost app: \(frontApp.localizedName ?? "Unknown") (pid: \(pid))")
        let appElement = AXUIElementCreateApplication(pid)
        var menuBar: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar)
        print("[DEBUG] AXUIElementCopyAttributeValue for kAXMenuBarAttribute result: \(result.rawValue)")
        guard result == .success, let menuBarCF = menuBar, CFGetTypeID(menuBarCF) == AXUIElementGetTypeID() else {
            print("[DEBUG] Failed to get menu bar element or wrong type.")
            return nil
        }
        let menuBarElement = unsafeBitCast(menuBarCF, to: AXUIElement.self)
        return parseMenuTree(from: menuBarElement)
    }

    private func parseMenuTree(from element: AXUIElement) -> [MenuNode] {
        var nodes: [MenuNode] = []
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement] else {
            return []
        }

        for child in childrenArray {
            var title: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            let titleStr = (title as? String) ?? ""

            var role: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
            let roleStr = role as? String ?? "unknown"

            var enabled: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabled)
            let enabledVal = (enabled as? Bool) ?? true

            var keyChar: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXMenuItemCmdCharAttribute as CFString, &keyChar)
            let keyEquivalent = (keyChar as? String) ?? ""

            var modifiers: AnyObject?
            AXUIElementCopyAttributeValue(child, kAXMenuItemCmdModifiersAttribute as CFString, &modifiers)
            var modifierMask: NSEvent.ModifierFlags = []
            if let modNumber = modifiers as? NSNumber {
                let intMod = modNumber.intValue
                var cgFlags = CGEventFlags()
                if (intMod & 1) != 0 { cgFlags.insert(.maskShift) }
                if (intMod & 2) != 0 { cgFlags.insert(.maskAlternate) }
                if (intMod & 4) != 0 { cgFlags.insert(.maskControl) }
                if (intMod & 8) != 0 { cgFlags.insert(.maskCommand) }
                modifierMask = NSEvent.ModifierFlags(rawValue: UInt(cgFlags.rawValue))
            }

            let subNodes = parseMenuTree(from: child)
            nodes.append(MenuNode(title: titleStr, role: roleStr, element: child, children: subNodes, enabled: enabledVal, keyEquivalent: keyEquivalent, keyEquivalentModifierMask: modifierMask))
        }
        return nodes
    }

    private func buildNSMenu(from nodes: [MenuNode]) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        for node in nodes {
            guard node.role == "AXMenuItem" else { continue }

            if node.title.isEmpty {
                menu.addItem(NSMenuItem.separator())
                continue
            }

            let item = NSMenuItem(title: node.title, action: nil, keyEquivalent: node.keyEquivalent.lowercased())
            item.keyEquivalentModifierMask = node.keyEquivalentModifierMask
            item.representedObject = node

            if let axMenuNode = node.children.first(where: { $0.role == "AXMenu" }) {
                item.submenu = buildNSMenu(from: axMenuNode.children)
            } else {
                item.action = #selector(menuItemClicked(_:))
                item.target = self
            }
            menu.addItem(item)
        }
        return menu
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let node = sender.representedObject as? MenuNode else { return }

        let result = AXUIElementPerformAction(node.element, kAXPressAction as CFString)
        if result != .success {
            print("Failed to perform action on menu item: \(node.title)")
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.isSeparatorItem {
            return true
        }
        
        guard let node = menuItem.representedObject as? MenuNode else {
            return menuItem.hasSubmenu
        }

        if menuItem.hasSubmenu {
            return true
        }

        return node.enabled
    }

    func handleTrigger() {
        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }
        guard let menuBarItems = fetchFrontmostAppMenuBar() else { return }

        let menu = NSMenu()
        menu.delegate = self

        for barItemNode in menuBarItems {
            guard barItemNode.role == "AXMenuBarItem", !barItemNode.title.isEmpty else { continue }

            let topLevelItem = NSMenuItem(title: barItemNode.title, action: nil, keyEquivalent: "")
            topLevelItem.representedObject = barItemNode

            if let axMenuNode = barItemNode.children.first(where: { $0.role == "AXMenu" }) {
                topLevelItem.submenu = buildNSMenu(from: axMenuNode.children)
            }
            menu.addItem(topLevelItem)
        }

        showMenuAtCursor(menu: menu)
    }

    private func showMenuAtCursor(menu: NSMenu) {
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }
}
