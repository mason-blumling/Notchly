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
    
    // Instantiate both managers.
    private let appleMusicManager: PlayerProtocol
    private let spotifyManager: PlayerProtocol
    
    // Store the last active player.
    private var lastActivePlayer: PlayerProtocol?
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Initialize with your existing managers.
        self.appleMusicManager = AppleMusicManager(notificationSubject: notificationSubject)
        self.spotifyManager = SpotifyManager(notificationSubject: notificationSubject)
    }
    
    /// Returns the currently active media player based on the following scenarios:
    /// 1. Neither app is running: returns nil (idle view).
    /// 2. Only Apple Music is running: returns Apple Music.
    /// 3. Only Spotify is running: returns Spotify.
    /// 4. Both are running:
    ///    - If one is playing, returns that one.
    ///    - If neither is playing, returns the default prioritized app (Spotify here).
    ///    - If both are playing, returns the prioritized app (Spotify by default).
    func getActivePlayer() -> PlayerProtocol? {
        let appleRunning = appleMusicManager.isAppRunning()
        let spotifyRunning = spotifyManager.isAppRunning()
        let applePlaying = appleRunning && appleMusicManager.isPlaying
        let spotifyPlaying = spotifyRunning && spotifyManager.isPlaying
        
        // Neither app running.
        if !appleRunning && !spotifyRunning {
            return nil
        }
        
        // Only one app is running.
        if appleRunning && !spotifyRunning {
            lastActivePlayer = appleMusicManager
            return appleMusicManager
        }
        if spotifyRunning && !appleRunning {
            lastActivePlayer = spotifyManager
            return spotifyManager
        }
        
        // Both are running.
        if applePlaying && !spotifyPlaying {
            lastActivePlayer = appleMusicManager
            return appleMusicManager
        } else if spotifyPlaying && !applePlaying {
            lastActivePlayer = spotifyManager
            return spotifyManager
        } else if applePlaying && spotifyPlaying {
            // Both are playing; choose based on user preference (here default to Spotify).
            lastActivePlayer = appleMusicManager
            return appleMusicManager
        } else {
            // Neither is playing; return the last active player if available.
            if let lastActive = lastActivePlayer {
                return lastActive
            } else {
                lastActivePlayer = appleMusicManager
                return appleMusicManager
            }
        }
    }
}
