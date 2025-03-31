//
//  MediaPlayerAppProvider.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI
import Combine

class MediaPlayerAppProvider {
    private var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    // Instantiate all three managers.
    private let appleMusicManager: PlayerProtocol
    private let spotifyManager: PlayerProtocol
    private let podcastsManager: PlayerProtocol
    
    // Store the last active player.
    private var lastActivePlayer: PlayerProtocol?
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Initialize with your existing managers.
        self.appleMusicManager = AppleMusicManager(notificationSubject: notificationSubject)
        self.spotifyManager = SpotifyManager(notificationSubject: notificationSubject)
        self.podcastsManager = PodcastsManager(notificationSubject: notificationSubject)
    }
    
    /// Returns the currently active media player.
    /// Maintains functionality: first check if the app is open, then if it’s playing.
    /// If none are playing, returns the last active player.
    func getActivePlayer() -> PlayerProtocol? {
        let appleRunning = appleMusicManager.isAppRunning()
        let spotifyRunning = spotifyManager.isAppRunning()
        let podcastsRunning = podcastsManager.isAppRunning()
        
        // Case 1: None are running.
        if !appleRunning && !spotifyRunning && !podcastsRunning {
            return nil
        }
        
        // Case 2: Only one is running.
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
        // Determine playing states.
        let applePlaying = appleRunning && appleMusicManager.isPlaying
        let spotifyPlaying = spotifyRunning && spotifyManager.isPlaying
        let podcastsPlaying = podcastsRunning && podcastsManager.isPlaying
        
        // If exactly one app is playing, choose that one.
        let playingApps: [PlayerProtocol] = [appleMusicManager, spotifyManager, podcastsManager].filter { $0.isPlaying }
        if playingApps.count == 1 {
            lastActivePlayer = playingApps.first
            return playingApps.first
        } else if playingApps.count > 1 {
            // If more than one is playing, use the last active if available and still playing.
            if let last = lastActivePlayer, last.isPlaying {
                return last
            } else {
                // Or choose a default priority (for example, Podcasts > Spotify > Apple Music).
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
        
        // Fallback (shouldn't happen)
        lastActivePlayer = appleMusicManager
        return appleMusicManager
    }
}
