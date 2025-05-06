//
//  Notchly+SBApplication.swift
//  Notchly
//
//  Created by Mason Blumling on 4/22/25.
//

import Foundation
import ScriptingBridge

extension SBApplication {
    /// Create an SBApplication for a bundle without ever auto-launching.
    static func application(
        url: URL,
        launchIfNeeded: Bool
    ) -> SBApplication? {
        /// Look up the private Obj-C selector
        let cls: AnyObject = SBApplication.self
        let sel = NSSelectorFromString("applicationWithURL:launchIfNeeded:")

        /// Bail if the class doesn’t respond
        guard cls.responds(to: sel) else {
            return nil
        }

        /// Perform the selector with two arguments
        let unmanaged = cls.perform(sel, with: url, with: launchIfNeeded)

        /// Extract and cast
        guard
            let sbApp = unmanaged?.takeUnretainedValue() as? SBApplication
        else {
            return nil
        }

        return sbApp
    }
}
