//
//  DefaultKeys.swift
//  Notchly
//
//  Created by Mason Blumling on 1/26/25.
//

import Foundation
import Defaults


enum NotchHeightMode: String, Defaults.Serializable {
    /// If there is no notch on display, measure height including the menu bar
    case displayWithNoNotch = "Display with no notch, measure including MenuBar"
    
    /// if the display has a notch, the height of the view matches the height of the display cutourt
    case displayWithNotch = "Display with notch, defaults to height of Display Cutout"
    
    /// TODO: Allow user to configure a custom notch-size to their liking
    case custom = "Custom height"
}

extension Defaults.Keys {
    
    static let notchHeightMode = Key<NotchHeightMode>("NotchHeightMode", default: NotchHeightMode.displayWithNotch)
    static let displayCutoutHeight = Key<CGFloat>("displayCutoutHeight", default: 32)
    static let defaultNotchWidth = Key<CGFloat>("defaultNotchWidth", default: 190)
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.25)
}
