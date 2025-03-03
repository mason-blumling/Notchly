//
//  NowPlayingHelper.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import Foundation
import AppKit

class NowPlayingHelper {
    static let shared = NowPlayingHelper()
    
    private let workspace = NSWorkspace.shared
    private var timer: Timer?
    
    init() {
        startListening()
    }
    
    /// 🔥 Starts a timer to check for active media every second
    func startListening() {
        stopListening() // Ensure no duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.fetchNowPlaying()
        }
    }
    
    /// 🚫 Stops listening for media changes
    func stopListening() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 📡 Fetches the currently active media player and updates NowPlayingManager
    private func fetchNowPlaying() {
        guard let app = workspace.frontmostApplication,
              let appName = app.localizedName else {
            NowPlayingManager.shared.clearTrack()
            return
        }

        print("🎵 Active App: \(appName)")

        if let trackInfo = getTrackInfo(for: appName) {
            NowPlayingManager.shared.updateTrack(
                title: trackInfo.title,
                artist: trackInfo.artist,
                albumArt: "album_art_placeholder", // TODO: Get actual artwork
                source: trackInfo.source
            )
        } else {
            NowPlayingManager.shared.clearTrack()
        }
    }
    
    /// 🛠 Extract track info based on the active app
    private func getTrackInfo(for appName: String) -> NowPlayingTrack? {
        switch appName {
        case "Music":
            return getAppleMusicInfo()
        case "Spotify":
            return getSpotifyInfo()
        case "YouTube":
            return getYouTubeInfo()
        default:
            return nil
        }
    }
    
    /// 🎵 Gets Apple Music Now Playing Info
    private func getAppleMusicInfo() -> NowPlayingTrack? {
        // TODO: Implement Apple Music scripting
        return nil
    }
    
    /// 🎧 Gets Spotify Now Playing Info
    private func getSpotifyInfo() -> NowPlayingTrack? {
        // TODO: Implement Spotify scripting
        return nil
    }

    /// 🎥 Gets YouTube Now Playing Info
    private func getYouTubeInfo() -> NowPlayingTrack? {
        // TODO: Implement YouTube playback detection
        return nil
    }
}
