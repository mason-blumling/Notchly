//
//  UserEmailCache.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//
//  This file handles fetching and caching the user's email addresses.
//  - Runs in the background to avoid UI delays.
//  - Retrieves emails from the calendar's default event source.
//  - Stores results in a cached set for quick lookups.
//

import Foundation
import EventKit

// MARK: - User Email Caching Extension

extension NotchlyEventList {
    
    /// Fetches and caches the user's email addresses in the background.
    func fetchAndCacheUserEmails() {
        DispatchQueue.global(qos: .background).async {
            let emails = fetchCurrentUserEmails()
            DispatchQueue.main.async {
                self.cachedUserEmails = emails
            }
        }
    }
    
    /// Retrieves the user's email addresses from the default calendar source.
    /// - Returns: A set of email addresses associated with the user's calendar.
    func fetchCurrentUserEmails() -> Set<String> {
        let eventStore = EKEventStore()
        
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source?.title,
           defaultSource.contains("@") {
            return [defaultSource.lowercased()]
        }
        
        return []
    }
}
