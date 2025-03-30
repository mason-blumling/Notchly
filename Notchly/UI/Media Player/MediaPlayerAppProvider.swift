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
        let appleMusicRunning = appleMusicManager.isAppRunning()
        let spotifyRunning = spotifyManager.isAppRunning()
        let appleMusicPlaying = appleMusicManager.isPlaying
        let spotifyPlaying = spotifyManager.isPlaying

        // Case 1: Neither is running.
        if !appleMusicRunning && !spotifyRunning {
            print("Neither Apple Music nor Spotify is running. Returning nil.")
            return nil
        }
        
        // Case 2: Only Apple Music is running.
        if appleMusicRunning && !spotifyRunning {
            print("Only Apple Music is running.")
            return appleMusicManager
        }
        
        // Case 3: Only Spotify is running.
        if spotifyRunning && !appleMusicRunning {
            print("Only Spotify is running.")
            return spotifyManager
        }
        
        // Case 4: Both are running.
        // Check their playing states.
        if appleMusicPlaying && !spotifyPlaying {
            print("Both running; Apple Music is playing and Spotify is not.")
            return appleMusicManager
        } else if spotifyPlaying && !appleMusicPlaying {
            print("Both running; Spotify is playing and Apple Music is not.")
            return spotifyManager
        } else if appleMusicPlaying && spotifyPlaying {
            // Both are playing; choose based on default priority.
            print("Both running and both playing; defaulting to Apple Music.")
            return appleMusicManager
        } else {
            // Neither is playing; choose default based on user preference (defaulting to Spotify).
            print("Both running but neither is playing; defaulting to Apple Music.")
            return appleMusicManager
        }
    }
}
