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

/// A protocol that defines the required media operations.
/// Future providers (e.g. Podcasts, Spotify) should conform to this.
protocol PlayerProtocol {
    var notificationSubject: PassthroughSubject<AlertItem, Never> { get set }
    
    var appName: String { get }
    var appPath: URL { get }
    var appNotification: String { get }
    var bundleIdentifier: String { get }
    var defaultAlbumArt: NSImage { get }
    
    var playerPosition: Double? { get }
    var isPlaying: Bool { get }
    var volume: CGFloat { get }
    
    /// Fetches now-playing information as a unified model.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void)
    
    /// Playback control methods.
    func playPause()
    func previousTrack()
    func nextTrack()
    func seekTo(time: TimeInterval)
    
    func setVolume(volume: Int)
    
    func isAppRunning() -> Bool
}

/// A simple alert type for notifications.
struct AlertItem: Error {
    let title: String
    let message: String
}

/// Struct to wrap fetched album art.
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
