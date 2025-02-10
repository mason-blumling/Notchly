//
//  NotchlyEventAttendees.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//
//  This file manages attendee-related logic for calendar events in Notchly.
//  - Detects pending responses.
//  - Identifies attendees who declined, responded "Maybe," or are awaiting responses.
//  - Ensures the event organizer is properly displayed.
//

import EventKit

// MARK: - Event Attendee Management Extension

extension NotchlyEventList {
    
    // MARK: - Pending & Awaiting Responses

    /// Checks if the current user has a pending response for the event.
    /// - Parameter event: The event to check.
    /// - Returns: `true` if the user has not responded yet.
    func isEventPending(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        return attendees.contains { attendee in
            attendee.isCurrentUser &&
            (attendee.participantStatus == .pending || attendee.participantStatus == .unknown)
        }
    }
    
    /// Checks if the event is waiting for responses from attendees.
    /// - Parameter event: The event to check.
    /// - Returns: `true` if the user is the organizer and some attendees have not responded.
    func isEventAwaitingResponses(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        let isOrganizer = event.organizer?.isCurrentUser ?? false
        return isOrganizer && attendees.contains { attendee in
            attendee.participantStatus == .pending || attendee.participantStatus == .unknown
        }
    }
    
    /// Fetches attendees who have not yet responded to the event.
    /// - Parameter event: The event to check.
    /// - Returns: A list of first names of attendees who have not responded.
    func awaitingAttendees(_ event: EKEvent) -> [String] {
        guard let attendees = event.attendees else { return [] }
        return attendees.compactMap { attendee in
            let firstName = attendee.name?.components(separatedBy: " ").first ?? "Unknown"
            return (attendee.participantStatus == .pending || attendee.participantStatus == .unknown) ? firstName : nil
        }
    }

    // MARK: - Attendee Status Filters

    /// Fetches attendees who **declined** the event, excluding the current user.
    /// - Parameter event: The event to check.
    /// - Returns: A list of attendee names who declined.
    func declinedAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .declined && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    /// Fetches attendees who **responded "Maybe"**, excluding the current user.
    /// - Parameter event: The event to check.
    /// - Returns: A list of attendee names who are tentative.
    func maybeAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .tentative && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    // MARK: - Event Organizer Handling

    /// Determines the event organizer and ensures it's not mistakenly displayed as the user.
    /// - Parameter event: The event to check.
    /// - Returns: The organizer's name, or `nil` if the user is the organizer.
    func eventOrganizer(_ event: EKEvent) -> String? {
        if event.organizer?.isCurrentUser == true {
            return nil
        }

        if let organizerName = event.organizer?.name {
            if cachedUserEmails.contains(organizerName.lowercased()) {
                return nil
            }
            return organizerName
        }

        return nil
    }
}
