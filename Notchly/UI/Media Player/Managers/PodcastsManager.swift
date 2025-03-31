//
//  PodcastsManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import Foundation
import AppKit
import ScriptingBridge
import SwiftUI
import Combine

// Wrote this prior to realizing Podcasts has no AppleScripting support... unable to leverage these methods until that exists without touching a private FW

// MARK: - Podcasts Scripting Protocols

/// Protocol representing a track in the Podcasts app.
/// Note: Podcasts doesn’t have proper AppleScript support, so these protocols are a placeholder.
@objc protocol PodcastTrack {
    var name: String { get }
    var artist: String { get }     // Typically the podcast author.
    var album: String { get }      // Typically the podcast title.
    var duration: Double { get }   // Duration in seconds.
    @objc optional func artworks() -> [Any]
}

/// Protocol representing the Podcasts app.
/// This protocol mirrors the structure used for Apple Music, but Podcasts lacks full support.
@objc protocol PodcastsApp {
    @objc optional var isRunning: Bool { get }
    @objc optional var playerState: Int { get } // We'll assume a similar numeric value as Apple Music (e.g., 1800426320 for playing).
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: PodcastTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional var soundVolume: Int { get }
}

/// Extend SBApplication so it conforms to PodcastsApp.
extension SBApplication: PodcastsApp {}

// MARK: - PodcastsManager Implementation

/// An implementation of PlayerProtocol for the Podcasts app.
/// Since Podcasts lacks proper AppleScript support, this implementation is a fallback.
/// It currently uses the same protocols as Apple Music.
final class PodcastsManager: PlayerProtocol {
    
    // MARK: - PlayerProtocol Conformance
    
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    /// The display name for the Podcasts app.
    var appName: String { "Podcasts" }
    /// The file path to the Podcasts app.
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Podcasts.app") }
    /// The notification string for Podcasts updates.
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    /// The bundle identifier for Podcasts, from constants.
    var bundleIdentifier: String { Constants.Podcasts.bundleID }
    /// The default artwork image.
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // MARK: - Private Properties
    
    /// Lazy property to avoid launching the Podcasts app unnecessarily.
    private lazy var podcastsApp: PodcastsApp? = {
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
        return podcastsApp?.playerPosition
    }
    
    var isPlaying: Bool {
        guard isAppRunning() else { return false }
        // Assume a similar playing value as Apple Music (e.g., 1800426320).
        return (podcastsApp?.playerState ?? 0) == 1800426320
    }
    
    var volume: CGFloat {
        return CGFloat(podcastsApp?.soundVolume ?? 50)
    }
    
    // MARK: - PlayerProtocol Methods
    
    /// Retrieves now-playing info from the Podcasts app and constructs a NowPlayingInfo model.
    /// Since Podcasts has no proper AppleScript support, this method might not fetch valid data.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Ensure the Podcasts app is running and has a current track.
        guard let podcastsApp = podcastsApp,
              let isRunning = podcastsApp.isRunning, isRunning,
              let track = podcastsApp.currentTrack else {
            completion(nil)
            return
        }
        
        let playingState = podcastsApp.playerState ?? 0
        let currentlyPlaying = (playingState == 1800426320)
        let elapsedTime = podcastsApp.playerPosition ?? 0.0
        let duration = track.duration
        
        // Attempt to fetch artwork using the same logic as for Apple Music.
        var artwork: NSImage? = nil
        if let artworksArray = track.artworks?(),
           let firstArtwork = artworksArray.first as? MusicArtwork, // Reusing MusicArtwork if no separate type exists.
           let image = firstArtwork.data,
           image.size != NSZeroSize {
            artwork = image
        } else {
            print("⚠️ Artwork image is empty or invalid for Podcasts.")
        }
        
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
    
    /// Toggles play/pause for Podcasts.
    func playPause() {
        podcastsApp?.playpause?()
    }
    
    /// Skips to the next track.
    func nextTrack() {
        podcastsApp?.nextTrack?()
    }
    
    /// Returns to the previous track.
    func previousTrack() {
        podcastsApp?.backTrack?()
    }
    
    /// Seeks to a specified time within the current track.
    func seekTo(time: TimeInterval) {
        if let sbObj = podcastsApp as? SBObject {
            sbObj.setValue(time, forKey: "playerPosition")
        }
    }
    
    /// Sets the volume.
    func setVolume(volume: Int) {
        if let sbObj = podcastsApp as? SBObject {
            sbObj.setValue(volume, forKey: "soundVolume")
        }
    }
    
    /// Checks if the Podcasts app is running.
    func isAppRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier)
        return !runningApps.isEmpty
    }
}
