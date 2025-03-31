//
//  AppleMusicManager.swift
//  Notchly
//
//  Created by Mason Blumling on 2025-03-XX.
//

import Foundation
import AppKit
import ScriptingBridge
import SwiftUI
import Combine

// MARK: - Apple Music Scripting Protocols

/// Represents a track in the Apple Music app.
@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }  // Duration in seconds.
    /// Returns an array of artwork objects.
    @objc optional func artworks() -> [Any]
}

/// Represents the Apple Music application.
@objc protocol AppleMusicApp {
    @objc optional var isRunning: Bool { get }
    @objc optional var playerState: Int { get } // e.g., 1800426320 means playing.
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: AppleMusicTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack() // previous track command.
    @objc optional var soundVolume: Int { get }
}

/// Extend SBApplication so that it conforms to AppleMusicApp.
extension SBApplication: AppleMusicApp {}

// MARK: - AppleMusicManager Implementation

/// An implementation of PlayerProtocol for Apple Music using ScriptingBridge.
final class AppleMusicManager: PlayerProtocol {
    
    // MARK: - PlayerProtocol Conformance
    
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    /// The display name for the media app.
    var appName: String { "Apple Music" }
    /// The file path to the Apple Music app.
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    /// The notification string used for Apple Music updates.
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    /// The bundle identifier retrieved from constants.
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    /// The default artwork image if none is available.
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // MARK: - Private Properties
    
    /// Lazy property to avoid launching the Apple Music app unless it’s running.
    private lazy var musicApp: AppleMusicApp? = {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !runningApps.isEmpty else { return nil }
        return SBApplication(bundleIdentifier: bundleIdentifier)
    }()
    
    // MARK: - Initialization
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    // MARK: - PlayerProtocol Computed Properties
    
    var playerPosition: Double? {
        return musicApp?.playerPosition
    }
    
    var isPlaying: Bool {
        // Ensure the app is running before checking state.
        guard isAppRunning() else { return false }
        return (musicApp?.playerState ?? 0) == 1800426320
    }
    
    var volume: CGFloat {
        return CGFloat(musicApp?.soundVolume ?? 50)
    }
    
    // MARK: - PlayerProtocol Methods
    
    /// Retrieves now-playing information from Apple Music and creates a unified NowPlayingInfo model.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Proceed only if the Apple Music app is running and has a current track.
        guard let musicApp = musicApp,
              let isRunning = musicApp.isRunning, isRunning,
              let track = musicApp.currentTrack else {
            completion(nil)
            return
        }
        
        let playingState = musicApp.playerState ?? 0
        let currentlyPlaying = (playingState == 1800426320)
        let elapsedTime = musicApp.playerPosition ?? 0.0
        let duration = track.duration
        
        // Attempt to extract artwork from the track.
        var artwork: NSImage? = nil
        if let artworksArray = track.artworks?(),
           let firstArtwork = artworksArray.first as? MusicArtwork,
           let image = firstArtwork.data,
           image.size != NSZeroSize {
            artwork = image
        } else {
            print("⚠️ Artwork image is empty or invalid.")
        }
        
        // Build the NowPlayingInfo model.
        let info = NowPlayingInfo(
            title: track.name,
            artist: track.artist,
            album: track.album,
            duration: duration,
            elapsedTime: elapsedTime,
            isPlaying: currentlyPlaying,
            artwork: artwork,
            appName: self.appName
        )
        completion(info)
    }
    
    /// Toggles play/pause state.
    func playPause() {
        musicApp?.playpause?()
    }
    
    /// Skips to the next track.
    func nextTrack() {
        musicApp?.nextTrack?()
    }
    
    /// Returns to the previous track.
    func previousTrack() {
        musicApp?.backTrack?()
    }
    
    /// Seeks to a specified time within the current track.
    func seekTo(time: TimeInterval) {
        if let sbObj = musicApp as? SBObject {
            sbObj.setValue(time, forKey: "playerPosition")
        }
    }
    
    /// Sets the sound volume.
    func setVolume(volume: Int) {
        if let sbObj = musicApp as? SBObject {
            sbObj.setValue(volume, forKey: "soundVolume")
        }
    }
    
    /// Checks if the Apple Music app is currently running.
    func isAppRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier)
        return !runningApps.isEmpty
    }
}
