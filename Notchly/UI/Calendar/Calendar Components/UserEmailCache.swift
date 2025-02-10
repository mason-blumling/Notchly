//
//  UserEmailCache.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import Foundation
import EventKit

extension NotchlyEventList {
    func fetchAndCacheUserEmails() {
        DispatchQueue.global(qos: .background).async {
            let emails = fetchCurrentUserEmails()
            DispatchQueue.main.async {
                self.cachedUserEmails = emails
            }
        }
    }
    
    /// Fetches all possible email addresses associated with the current user.
    func fetchCurrentUserEmails() -> Set<String> {
        let eventStore = EKEventStore()
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source?.title,
           defaultSource.contains("@") {
            return [defaultSource.lowercased()]
        }
        return []
    }
}
