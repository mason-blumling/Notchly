//
//  SpotifyManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import os
import Combine
import Foundation
import AppKit
import SwiftUI
import ScriptingBridge

// MARK: - SpotifyManager Implementation

/// An implementation of PlayerProtocol for Spotify using ScriptingBridge.
/// It lazily instantiates the SpotifyApplication only if Spotify is running.
class SpotifyManager: PlayerProtocol {
    
    // MARK: - PlayerProtocol Conformance
    
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    /// The bundle identifier for Spotify (from constants).
    public var bundleIdentifier: String { Constants.Spotify.bundleID }
    /// The display name for Spotify.
    public var appName: String { "Spotify" }
    /// The file path to the Spotify app.
    public var appPath: URL = URL(fileURLWithPath: "/Applications/Spotify.app")
    /// The notification string for Spotify playback state changes.
    public var appNotification: String { "\(bundleIdentifier).PlaybackStateChanged" }
    /// The default album art if none is available.
    public var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // MARK: - Lazy Initialization
    
    /// Lazily instantiated SpotifyApplication. It is only set if Spotify is already running.
    private lazy var app: SpotifyApplication? = {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Constants.Spotify.bundleID)
        guard !runningApps.isEmpty else { return nil }
        return SBApplication(bundleIdentifier: Constants.Spotify.bundleID)
    }()
    
    // MARK: - Computed Properties
    
    /// The current playback position in seconds.
    public var playerPosition: Double? {
        return app?.playerPosition
    }
    
    /// Returns true if Spotify is running and its state indicates it's playing.
    public var isPlaying: Bool {
        guard isAppRunning() else { return false }
        return app?.playerState == .playing
    }
    
    /// Returns the current sound volume.
    public var volume: CGFloat {
        return CGFloat(app?.soundVolume ?? 50)
    }
    
    // MARK: - Initialization
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    // MARK: - PlayerProtocol Methods
    
    /// Fetches the now-playing information from Spotify and returns a unified NowPlayingInfo model.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Ensure Spotify is running and a current track exists.
        guard isAppRunning(), let track = app?.currentTrack else {
            completion(nil)
            return
        }
        
        // Gather basic track details.
        let title = track.name ?? "Unknown Title"
        let artist = track.artist ?? "Unknown Artist"
        let album = track.album ?? "Unknown Album"
        
        // Spotify returns duration in milliseconds; convert it to seconds.
        let durationSeconds = Double(track.duration ?? 0) / 1000.0
        let elapsedTime = app?.playerPosition ?? 0.0
        
        // Attempt to fetch album artwork from the provided artworkUrl.
        if let urlString = track.artworkUrl, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                var artwork: NSImage? = nil
                if let data = data, let image = NSImage(data: data) {
                    artwork = image
                } else {
                    print("Error fetching Spotify album image: \(error?.localizedDescription ?? "Unknown error")")
                }
                let info = NowPlayingInfo(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: durationSeconds,
                    elapsedTime: elapsedTime,
                    isPlaying: self.isPlaying,
                    artwork: artwork,
                    appName: self.appName
                )
                DispatchQueue.main.async {
                    completion(info)
                }
            }.resume()
        } else {
            // If no artwork URL is provided, return the basic info.
            let info = NowPlayingInfo(
                title: title,
                artist: artist,
                album: album,
                duration: durationSeconds,
                elapsedTime: elapsedTime,
                isPlaying: self.isPlaying,
                artwork: nil,
                appName: self.appName
            )
            completion(info)
        }
    }
    
    /// Toggles the play/pause state in Spotify.
    func playPause() {
        app?.playpause?()
    }
    
    /// Skips to the previous track.
    func previousTrack() {
        app?.previousTrack?()
    }
    
    /// Skips to the next track.
    func nextTrack() {
        app?.nextTrack?()
    }
    
    /// Seeks to the specified time within the current track.
    func seekTo(time: TimeInterval) {
        app?.setPlayerPosition?(time)
    }
    
    /// Sets the sound volume.
    func setVolume(volume: Int) {
        app?.setSoundVolume?(volume)
    }
    
    /// Checks whether Spotify is currently running.
    func isAppRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier)
        return !runningApps.isEmpty
    }
}
