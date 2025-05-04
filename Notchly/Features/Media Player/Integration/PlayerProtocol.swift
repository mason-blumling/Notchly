//
//  PlayerProtocol.swift
//  Notchly
//
//  Created by Mason Blumling on 3-27-2025.
//

import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - PlayerProtocol Definition

/// A protocol that defines required media operations.
/// All media app implementations (Apple Music, Spotify, Podcasts) must conform to this.
protocol PlayerProtocol {
    
    // MARK: - Notification

    /// Subject used to emit alert notifications.
    var notificationSubject: PassthroughSubject<AlertItem, Never> { get set }
    
    // MARK: - Application Identity

    /// Display name of the media application.
    var appName: String { get }

    /// File path to the application.
    var appPath: URL { get }

    /// DistributedNotification name used for listening to updates.
    var appNotification: String { get }

    /// App's bundle identifier.
    var bundleIdentifier: String { get }

    /// Default artwork to show if none is provided.
    var defaultAlbumArt: NSImage { get }

    // MARK: - Playback State Properties

    /// Current playback time (seconds).
    var playerPosition: Double? { get }

    /// Indicates if the app is currently playing audio.
    var isPlaying: Bool { get }

    /// Current volume level (0.0–1.0).
    var volume: CGFloat { get }

    // MARK: - Playback Operations

    /// Fetches now-playing metadata (title, artist, artwork, etc.).
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void)

    /// Toggles play/pause playback.
    func playPause()

    /// Skips to previous track.
    func previousTrack()

    /// Skips to next track.
    func nextTrack()

    /// Seeks to a specific timestamp in the current track.
    func seekTo(time: TimeInterval)

    /// Sets the app’s volume.
    func setVolume(volume: Int)

    /// Returns true if the app is currently running.
    func isAppRunning() -> Bool
}

// MARK: - Supporting Types

/// A simple error wrapper for alert messaging.
struct AlertItem: Error {
    let title: String
    let message: String
}

/// Wraps artwork as both SwiftUI and AppKit representations.
struct FetchedAlbumArt {
    let image: Image
    let nsImage: NSImage
}

/// Unified structure for now-playing media metadata.
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var artwork: NSImage?
    var appName: String
}
