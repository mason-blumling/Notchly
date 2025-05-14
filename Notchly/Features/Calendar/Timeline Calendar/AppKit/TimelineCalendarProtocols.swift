//
//  TimelineCalendarProtocols.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import Foundation
import AppKit
import EventKit
import SwiftUI

/// MARK: - Protocol Definitions

/// Protocol for calendar view to communicate with SwiftUI
protocol TimelineCalendarDelegate: AnyObject {
    func didSelectDate(_ date: Date)
}

/// Protocol for date selector to communicate with container
protocol TimelineDateSelectorDelegate: AnyObject {
    func didSelectDate(_ date: Date)
}
