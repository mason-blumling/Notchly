//
//  NotchlyLayoutGuide.swift
//  Notchly
//
//  Created by Mason Blumling on 5/2/25.
//

import Foundation
import SwiftUI

struct NotchlyLayoutGuide {
    // Full bounds including the corners
    let bounds: CGRect
    
    // Safe area for content (avoiding corners)
    let safeBounds: CGRect
    
    // Current notch state
    let state: NotchlyTransitionCoordinator.NotchState
    
    // Content dimensions
    var contentWidth: CGFloat { safeBounds.width }
    var contentHeight: CGFloat { safeBounds.height }
    
    // Left content area (for media player in expanded state)
    var leftContentFrame: CGRect {
        // Adjust the media player frame to be exactly on left half
        CGRect(
            x: safeBounds.minX,
            y: safeBounds.minY,
            width: safeBounds.width * 0.47, // Slightly less than half
            height: safeBounds.height
        )
    }
    
    // Right content area (for calendar in expanded state)
    var rightContentFrame: CGRect {
        // Adjust the calendar frame to be exactly on right half
        CGRect(
            x: safeBounds.minX + safeBounds.width * 0.48, // Small spacing between
            y: safeBounds.minY,
            width: safeBounds.width * 0.47, // Slightly less than half
            height: safeBounds.height
        )
    }
    
    // Full content area (for single-component views)
    var fullContentFrame: CGRect { safeBounds }
    
    // Media activity area (for compact state)
    var mediaActivityFrame: CGRect {
        CGRect(
            x: safeBounds.minX + 10,
            y: safeBounds.minY,
            width: safeBounds.width - 20,
            height: safeBounds.height
        )
    }
    
    // Calendar activity area (for live alerts)
    var calendarActivityFrame: CGRect { mediaActivityFrame }
}
