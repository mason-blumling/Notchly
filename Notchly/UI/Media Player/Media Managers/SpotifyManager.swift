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

class SpotifyManager: PlayerProtocol {
    // Use the SpotifyApplication defined in SpotifyApp.swift.
    var app: SpotifyApplication = SBApplication(bundleIdentifier: Constants.Spotify.bundleID)!
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    
    // MARK: - PlayerProtocol Conformance
    public var bundleIdentifier: String { Constants.Spotify.bundleID }
    public var appName: String { "Spotify" }
    public var appPath: URL = URL(fileURLWithPath: "/Applications/Spotify.app")
    public var appNotification: String { "\(bundleIdentifier).PlaybackStateChanged" }
    public var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }

    public var playerPosition: Double? { app.playerPosition }
    public var isPlaying: Bool { app.playerState == .playing }
    public var volume: CGFloat { CGFloat(app.soundVolume ?? 50) }
    
    // MARK: - Initialization
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
    }
    
    // MARK: - PlayerProtocol Methods
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Ensure Spotify is running and there is a current track.
        guard isAppRunning(), let track = app.currentTrack else {
            completion(nil)
            return
        }
        
        let title = track.name ?? "Unknown Title"
        let artist = track.artist ?? "Unknown Artist"
        let album = track.album ?? "Unknown Album"
        // Spotify's duration is defined as an Int (seconds) in your SpotifyApp.swift.
        let durationSeconds = Double(track.duration ?? 0)
        let elapsedTime = app.playerPosition ?? 0.0
        
        // Attempt to fetch album artwork from artworkUrl.
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
    
    func playPause() {
        app.playpause?()
    }
    
    func previousTrack() {
        app.previousTrack?()
    }
    
    func nextTrack() {
        app.nextTrack?()
    }
    
    func seekTo(time: TimeInterval) {
        app.setPlayerPosition?(time)
    }
    
    func setVolume(volume: Int) {
        app.setSoundVolume?(volume)
    }
    
    func isAppRunning() -> Bool {
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == self.bundleIdentifier }
    }
}
