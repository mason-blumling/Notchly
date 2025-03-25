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
