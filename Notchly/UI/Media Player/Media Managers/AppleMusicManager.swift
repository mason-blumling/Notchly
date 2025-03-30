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

/// Protocol representing a track in the Music app.
@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }  // Duration in seconds.
    /// This function returns an array of artwork objects.
    @objc optional func artworks() -> [Any]
}

/// Protocol representing the Music app.
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

/// Extend SBApplication so it conforms to AppleMusicApp.
extension SBApplication: AppleMusicApp {}

// MARK: - AppleMusicManager Implementation

/// An implementation of PlayerProtocol using Apple Music’s scripting interface.
final class AppleMusicManager: PlayerProtocol {
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    var playerPosition: Double? { musicApp.playerPosition }
    var isPlaying: Bool { (musicApp.playerState ?? 0) == 1800426320 }
    var volume: CGFloat { CGFloat(musicApp.soundVolume ?? 50) }
    
    // MARK: - Private Property
    /// Returns the Apple Music app instance.
    private var musicApp: AppleMusicApp {
        SBApplication(bundleIdentifier: bundleIdentifier)!
    }
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    /// Retrieves now-playing info from Apple Music and converts it into a NowPlayingInfo model.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Ensure the Music app is running and a track is available.
        guard let isRunning = musicApp.isRunning, isRunning,
              let track = musicApp.currentTrack else {
            completion(nil)
            return
        }
        
        let playingState = musicApp.playerState ?? 0
        let currentlyPlaying = (playingState == 1800426320)
        let elapsedTime = musicApp.playerPosition ?? 0.0
        let duration = track.duration
        
        // Attempt to extract artwork.
        var artwork: NSImage? = nil
        if let artworksArray = track.artworks?(),
           let firstArtwork = artworksArray.first as? MusicArtwork,
           let image = firstArtwork.data,
           image.size != NSZeroSize {
            artwork = image
        } else {
            print("⚠️ Artwork image is empty or invalid.")
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
    
    func playPause() {
        musicApp.playpause?()
    }
    
    func nextTrack() {
        musicApp.nextTrack?()
    }
    
    func previousTrack() {
        musicApp.backTrack?()
    }
    
    func seekTo(time: TimeInterval) {
        if let sbObj = musicApp as? SBObject {
            sbObj.setValue(time, forKey: "playerPosition")
        }
    }
    
    func setVolume(volume: Int) {
        if let sbObj = musicApp as? SBObject {
            sbObj.setValue(volume, forKey: "soundVolume")
        }
    }
    
    func isAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == bundleIdentifier
        }
    }
}

/// Constants used by the provider.
enum Constants {
    enum AppInfo {
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    enum Spotify {
        static let bundleID = "com.spotify.client"
    }
    
    enum AppleMusic {
        static let bundleID = "com.apple.Music"
    }
}
