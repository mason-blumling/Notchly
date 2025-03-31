//
//  MediaPlayerAppProvider.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI
import Combine

// MARK: - MediaPlayerAppProvider

/// Provides the currently active media player instance by determining which media app (Apple Music, Spotify, or Podcasts)
/// is running and, if more than one is running, which one is currently playing. If none are playing, it falls back to the last active player.
class MediaPlayerAppProvider {
    
    // MARK: - Private Properties
    
    /// Notification subject for alert messages.
    private var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    /// Instances of media managers.
    private let appleMusicManager: PlayerProtocol
    private let spotifyManager: PlayerProtocol
    private let podcastsManager: PlayerProtocol
    
    /// The last active player used as a fallback when no app is actively playing.
    private var lastActivePlayer: PlayerProtocol?
    
    // MARK: - Initialization
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Initialize media managers with the shared notification subject.
        self.appleMusicManager = AppleMusicManager(notificationSubject: notificationSubject)
        self.spotifyManager = SpotifyManager(notificationSubject: notificationSubject)
        self.podcastsManager = PodcastsManager(notificationSubject: notificationSubject)
    }
    
    // MARK: - Public Methods
    
    /// Returns the currently active media player based on running and playing states.
    ///
    /// - Returns: A PlayerProtocol instance if one or more media apps are running; otherwise, nil.
    func getActivePlayer() -> PlayerProtocol? {
        let appleRunning = appleMusicManager.isAppRunning()
        let spotifyRunning = spotifyManager.isAppRunning()
        let podcastsRunning = podcastsManager.isAppRunning()
        
        // Case 1: None of the apps are running.
        if !appleRunning && !spotifyRunning && !podcastsRunning {
            return nil
        }
        
        // Case 2: Only one app is running.
        if appleRunning && !spotifyRunning && !podcastsRunning {
            lastActivePlayer = appleMusicManager
            return appleMusicManager
        }
        if spotifyRunning && !appleRunning && !podcastsRunning {
            lastActivePlayer = spotifyManager
            return spotifyManager
        }
        if podcastsRunning && !appleRunning && !spotifyRunning {
            lastActivePlayer = podcastsManager
            return podcastsManager
        }
        
        // Case 3: Multiple apps are running.
        // Check the playing state for each.
        let applePlaying = appleRunning && appleMusicManager.isPlaying
        let spotifyPlaying = spotifyRunning && spotifyManager.isPlaying
        let podcastsPlaying = podcastsRunning && podcastsManager.isPlaying
        
        // If exactly one app is playing, choose that one.
        let playingApps: [PlayerProtocol] = [appleMusicManager, spotifyManager, podcastsManager].filter { $0.isPlaying }
        if playingApps.count == 1 {
            lastActivePlayer = playingApps.first
            return playingApps.first
        } else if playingApps.count > 1 {
            // If more than one app is playing, return the last active one if it's still playing.
            if let last = lastActivePlayer, last.isPlaying {
                return last
            } else {
                // Otherwise, choose based on a default priority.
                // Priority: Podcasts > Spotify > Apple Music.
                if podcastsPlaying {
                    lastActivePlayer = podcastsManager
                    return podcastsManager
                }
                if spotifyPlaying {
                    lastActivePlayer = spotifyManager
                    return spotifyManager
                }
                if applePlaying {
                    lastActivePlayer = appleMusicManager
                    return appleMusicManager
                }
            }
        }
        
        // If none are playing but more than one is open, return the last active player.
        if let last = lastActivePlayer {
            return last
        }
        
        // Fallback: default to Apple Music.
        lastActivePlayer = appleMusicManager
        return appleMusicManager
    }
}
