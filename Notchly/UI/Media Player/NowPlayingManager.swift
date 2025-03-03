//
//  NowPlayingManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import Foundation
import Combine

class NowPlayingManager: ObservableObject {
    @Published var nowPlaying: NowPlayingTrack? = nil // Updates when media changes

    // Simulating media state change (replace this with actual media tracking logic)
    func updateTrack(title: String, artist: String, albumArt: String, source: MusicSource) {
        nowPlaying = NowPlayingTrack(title: title, artist: artist, albumArt: albumArt, source: source)
    }

    func clearTrack() {
        nowPlaying = nil
    }
    
    // Temporary function for debugging
    func simulateNowPlaying() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { // Simulate delay
            self.nowPlaying = NowPlayingTrack(
                title: "679 (feat. Remy Boyz)",
                artist: "Fetty Wap",
                albumArt: "album_art_placeholder",
                source: .appleMusic
            )
            print("🎵 NowPlayingManager updated: \(self.nowPlaying?.title ?? "None")")
        }
    }
}
