//
//  MediaPlaybackTypes.swift
//  Notchly
//
//  Created by Mason Blumling on 3/19/25.
//

import AppKit

// MARK: - NowPlayingInfo
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

// MARK: - SpotifyAuth
struct SpotifyAuth {
    let accessToken: String
    let refreshToken: String
}

// MARK: - MusicApplication (ScriptingBridge)
@objc protocol MusicApplication {
    var playerState: Int { get } // Use Int instead of MusicEPlS
    var playerPosition: Double { get set } // Use Double instead of TimeInterval
    func playpause()
}

// MARK: - MusicEPlS (Raw Values for Apple Music)
enum MusicEPlS: Int {
    case stopped = 0x6b505353
    case playing = 0x6b50534C
    case paused = 0x6b505350
}

// MARK: - PlayerType
enum PlayerType {
    case appleMusic
    case spotify
    case other
}
