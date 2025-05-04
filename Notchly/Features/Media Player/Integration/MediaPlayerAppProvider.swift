//
//  MediaPlayerAppProvider.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI
import Combine

// MARK: - MediaPlayerAppProvider

/// Provides the currently active media player instance (Apple Music, Spotify, or Podcasts).
/// - Selects the app that is actively playing.
/// - Falls back to the last used player if none are playing.
/// - Prioritizes Apple Music > Spotify > Podcasts in conflict.
class MediaPlayerAppProvider {
    
    // MARK: - Private Properties

    /// Notification subject for sending alerts to UI.
    private var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    /// Instances of the supported media player managers.
    private let appleMusicManager: PlayerProtocol
    private let spotifyManager: PlayerProtocol
    private let podcastsManager: PlayerProtocol
    
    /// Tracks the last known active player, used as a fallback.
    private var lastActivePlayer: PlayerProtocol?
    
    // MARK: - Initialization

    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Initialize all media player managers
        self.appleMusicManager = AppleMusicManager(notificationSubject: notificationSubject)
        self.spotifyManager = SpotifyManager(notificationSubject: notificationSubject)
        self.podcastsManager = PodcastsManager(notificationSubject: notificationSubject)
    }
    
    // MARK: - Public Methods

    /// Determines and returns the currently active media player.
    /// - Returns: The `PlayerProtocol` instance representing the active player, or nil if none are running.
    func getActivePlayer() -> PlayerProtocol? {
        let appleRunning = appleMusicManager.isAppRunning()
        let spotifyRunning = spotifyManager.isAppRunning()
        let podcastsRunning = podcastsManager.isAppRunning()
        
        /// Case 1: No media apps running
        if !appleRunning && !spotifyRunning && !podcastsRunning {
            return nil
        }
        
        /// Case 2: Only one media app is running
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
        
        /// Case 3: Multiple apps running — check which are playing
        let applePlaying = appleRunning && appleMusicManager.isPlaying
        let spotifyPlaying = spotifyRunning && spotifyManager.isPlaying
        let podcastsPlaying = podcastsRunning && podcastsManager.isPlaying
        
        let playingApps: [PlayerProtocol] = [appleMusicManager, spotifyManager, podcastsManager].filter { $0.isPlaying }
        
        /// Exactly one app playing → use it
        if playingApps.count == 1 {
            lastActivePlayer = playingApps.first
            return playingApps.first
        }
        
        /// Multiple apps playing → prefer last used if valid
        if let last = lastActivePlayer, last.isPlaying {
            return last
        }

        /// Choose based on priority: Music > Spotify > Podcasts
        if applePlaying {
            lastActivePlayer = appleMusicManager
            return appleMusicManager
        }
        if spotifyPlaying {
            lastActivePlayer = spotifyManager
            return spotifyManager
        }
        if podcastsPlaying {
            lastActivePlayer = podcastsManager
            return podcastsManager
        }
        
        /// Case 4: None playing but multiple open → return last active if possible
        if let last = lastActivePlayer {
            return last
        }
        
        /// Fallback: default to Apple Music
        lastActivePlayer = appleMusicManager
        return appleMusicManager
    }
}
