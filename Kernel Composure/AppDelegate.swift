//
//  AppDelegate.swift
//  Kernel Composure
//
//  Created by Tyler Sparr on 5/17/20.
//  Copyright © 2020 Encore Technologies. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var filename: String = ""
    
//  Accepts a file via "Open With" and does an automatic parsing run
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        self.filename = filename
        let fileUrl = URL(fileURLWithPath: filename)
        guard let main = NSApp.mainWindow?.contentViewController as! ViewController? else { return true }
        main.automatic_run(fileUrl)
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

