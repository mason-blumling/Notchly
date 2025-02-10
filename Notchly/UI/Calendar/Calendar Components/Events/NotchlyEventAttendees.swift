//
//  NotchlyEventAttendees.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import EventKit

extension NotchlyEventList {
    
    func isEventPending(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        return attendees.contains { attendee in
            attendee.isCurrentUser &&
            (attendee.participantStatus == .pending || attendee.participantStatus == .unknown)
        }
    }
    
    func isEventAwaitingResponses(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        let isOrganizer = event.organizer?.isCurrentUser ?? false
        return isOrganizer && attendees.contains { attendee in
            attendee.participantStatus == .pending || attendee.participantStatus == .unknown
        }
    }
    
    func awaitingAttendees(_ event: EKEvent) -> [String] {
        guard let attendees = event.attendees else { return [] }
        return attendees.compactMap { attendee in
            let firstName = attendee.name?.components(separatedBy: " ").first ?? "Unknown"
            return (attendee.participantStatus == .pending || attendee.participantStatus == .unknown) ? firstName : nil
        }
    }

    /// Fetches declined attendees, excluding the current user.
    func declinedAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .declined && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    /// Fetches attendees who responded "Maybe," excluding the current user.
    func maybeAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .tentative && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    /// Determines the event organizer and ensures it's not the current user.
    func eventOrganizer(_ event: EKEvent) -> String? {
        if event.organizer?.isCurrentUser == true {
            print("🔹 Skipping organizer because it's the current user: \(event.organizer?.name ?? "Unknown")")
            return nil
        }

        if let organizerName = event.organizer?.name {
            if cachedUserEmails.contains(organizerName.lowercased()) {
                print("🔹 Skipping organizer \(organizerName) because it's my own email")
                return nil
            }
            return organizerName
        }

        return nil
    }
}
