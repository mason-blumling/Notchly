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

/// A protocol that defines the required media operations.
/// All media player implementations (e.g., Apple Music, Spotify, Podcasts) must conform to this protocol.
protocol PlayerProtocol {
    // MARK: - Notification
    /// A subject used to send alert notifications.
    var notificationSubject: PassthroughSubject<AlertItem, Never> { get set }
    
    // MARK: - Application Identity
    /// The display name of the media application.
    var appName: String { get }
    /// The file URL to the media application.
    var appPath: URL { get }
    /// The notification string used for app-specific updates.
    var appNotification: String { get }
    /// The bundle identifier of the media application.
    var bundleIdentifier: String { get }
    /// The default album art image to use if none is available.
    var defaultAlbumArt: NSImage { get }
    
    // MARK: - Playback State Properties
    /// The current playback position in seconds.
    var playerPosition: Double? { get }
    /// A Boolean indicating whether the media is currently playing.
    var isPlaying: Bool { get }
    /// The current volume level of the media.
    var volume: CGFloat { get }
    
    // MARK: - Playback Operations
    /// Fetches now-playing information as a unified model.
    /// - Parameter completion: A closure called with an optional NowPlayingInfo model.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void)
    
    /// Toggles play/pause for the media application.
    func playPause()
    /// Skips to the previous track.
    func previousTrack()
    /// Skips to the next track.
    func nextTrack()
    /// Seeks to a specific time within the current track.
    /// - Parameter time: The target time in seconds.
    func seekTo(time: TimeInterval)
    
    /// Sets the sound volume.
    /// - Parameter volume: The volume level as an integer.
    func setVolume(volume: Int)
    
    /// Checks if the media application is currently running.
    /// - Returns: True if the app is running, false otherwise.
    func isAppRunning() -> Bool
}

// MARK: - Supporting Types

/// A simple alert type for sending notifications.
struct AlertItem: Error {
    let title: String
    let message: String
}

/// Wraps album art data, providing both a SwiftUI Image and an NSImage.
struct FetchedAlbumArt {
    let image: Image
    let nsImage: NSImage
}

/// A unified model representing the current media state.
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
