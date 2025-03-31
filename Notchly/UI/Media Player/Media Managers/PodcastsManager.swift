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
@objc protocol PodcastTrack {
    var name: String { get }
    var artist: String { get }     // Typically the podcast author
    var album: String { get }      // Typically the podcast title
    var duration: Double { get }   // Duration in seconds.
    @objc optional func artworks() -> [Any]
}

/// Protocol representing the Podcasts app.
@objc protocol PodcastsApp {
    @objc optional var isRunning: Bool { get }
    @objc optional var playerState: Int { get } // We'll assume a similar numeric value as Apple Music (e.g., 1800426320 for playing)
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

/// An implementation of PlayerProtocol using the Podcasts app’s scripting interface.
final class PodcastsManager: PlayerProtocol {
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    var appName: String { "Podcasts" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Podcasts.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.Podcasts.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // Use a lazy optional to avoid launching the Podcasts app unintentionally.
    private lazy var podcastsApp: PodcastsApp? = {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !runningApps.isEmpty else { return nil }
        return SBApplication(bundleIdentifier: bundleIdentifier)
    }()
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    var playerPosition: Double? {
        return podcastsApp?.playerPosition
    }
    
    var isPlaying: Bool {
        guard isAppRunning() else { return false }
        // Assuming the same playing value as Apple Music (e.g., 1800426320)
        return (podcastsApp?.playerState ?? 0) == 1800426320
    }
    
    var volume: CGFloat {
        return CGFloat(podcastsApp?.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Ensure the Podcasts app is running and there is a current track.
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
        
        var artwork: NSImage? = nil
        if let artworksArray = track.artworks?(),
           let firstArtwork = artworksArray.first as? MusicArtwork, // You can reuse MusicArtwork if Podcasts doesn't provide a separate type.
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
    
    func playPause() {
        podcastsApp?.playpause?()
    }
    
    func nextTrack() {
        podcastsApp?.nextTrack?()
    }
    
    func previousTrack() {
        podcastsApp?.backTrack?()
    }
    
    func seekTo(time: TimeInterval) {
        if let sbObj = podcastsApp as? SBObject {
            sbObj.setValue(time, forKey: "playerPosition")
        }
    }

    func setVolume(volume: Int) {
        if let sbObj = podcastsApp as? SBObject {
            sbObj.setValue(volume, forKey: "soundVolume")
        }
    }
    
    func isAppRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: self.bundleIdentifier)
        return !runningApps.isEmpty
    }
}
