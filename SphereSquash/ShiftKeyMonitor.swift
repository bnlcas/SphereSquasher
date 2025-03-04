//
//  ShiftKeyMonitor.swift
//  SphereSquash
//
//  Created by Benjamin Lucas on 3/3/25.
//

import AppKit
import Combine

class ShiftKeyMonitor: ObservableObject {
    @Published var shiftDown: Bool = false
    
    private var monitor: Any?
    
    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            DispatchQueue.main.async {
                self.shiftDown = event.modifierFlags.contains(.shift)
            }
            return event
        }
    }
    
    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
