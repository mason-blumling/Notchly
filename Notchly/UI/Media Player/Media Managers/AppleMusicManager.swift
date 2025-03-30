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

@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }  // Duration in seconds.
    @objc optional func artworks() -> [Any]
}

@objc protocol AppleMusicApp {
    @objc optional var isRunning: Bool { get }
    @objc optional var playerState: Int { get } // e.g., 1800426320 means playing.
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: AppleMusicTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional var soundVolume: Int { get }
}

extension SBApplication: AppleMusicApp {}

// MARK: - AppleMusicManager Implementation

final class AppleMusicManager: PlayerProtocol {
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    /// Use a lazy optional property to avoid launching the app.
    private lazy var musicApp: AppleMusicApp? = {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !runningApps.isEmpty else { return nil }
        return SBApplication(bundleIdentifier: bundleIdentifier)
    }()
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    var playerPosition: Double? {
        return musicApp?.playerPosition
    }
    
    var isPlaying: Bool {
        return (musicApp?.playerState ?? 0) == 1800426320
    }
    
    var volume: CGFloat {
        return CGFloat(musicApp?.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Only proceed if the app is running.
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
        musicApp?.playpause?()
    }
    
    func nextTrack() {
        musicApp?.nextTrack?()
    }
    
    func previousTrack() {
        musicApp?.backTrack?()
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
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier)
        return !runningApps.isEmpty
    }
}

/// Constants used by the provider.
enum Constants {
    enum AppleMusic {
        static let bundleID = "com.apple.Music"
    }
    enum Spotify {
        static let bundleID = "com.spotify.client"
    }
}
