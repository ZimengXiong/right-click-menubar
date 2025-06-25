//
//  AppDelegate.swift
//  Right Click Menubar
//
//  All Content Copyright 2025 Zimeng Xiong.
//  All rights reserved.
//  Created by Zimeng Xiong on 6/23/25.
//
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menuManager: MenuManager!
    var preferencesWindow: NSWindow?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuManager = MenuManager()
        setupStatusItemMenu()
        showPreferences()
        NSApp.servicesProvider = self
    }

    @objc func terminate(_ sender: Any?) {
        hideAllWindows()
        NSApp.setActivationPolicy(.accessory)
    }

    func setupStatusItemMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            var image = NSImage(named: "MenuIcon")
            if image == nil {
                if let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png") {
                    image = NSImage(contentsOf: url)
                }
            }
            if image == nil {
                print("[MenuBar] Could not load menu bar icon image! Check Assets.xcassets or bundle for 'MenuIcon'.")
            }
            image?.size = NSSize(width: 18, height: 18)
            button.image = image
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }
    }

    lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Right Click Menubar", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferencesMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        return menu
    }()

    @objc func statusItemClicked(_ sender: Any?) {
        if let button = statusItem?.button {
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
        }
    }

    func showPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesView()
            let hostingController = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 450, height: 350))
            window.delegate = self
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferencesMenu() {
        showPreferences()
    }

    @objc func hideAllWindows() {
        preferencesWindow?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == preferencesWindow {
            preferencesWindow?.orderOut(nil)
        }
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
