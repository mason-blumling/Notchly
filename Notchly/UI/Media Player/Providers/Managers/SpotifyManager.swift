//
//  SpotifyManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import Combine
import Foundation
import AppKit
import SwiftUI
import ScriptingBridge

final class SpotifyManager: PlayerProtocol {
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var bundleIdentifier: String { Constants.Spotify.bundleID }
    var appName: String { "Spotify" }
    var appPath: URL { URL(fileURLWithPath: "/Applications/Spotify.app") }
    var appNotification: String { "\(bundleIdentifier).PlaybackStateChanged" }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    private var app: SpotifyApplication?
    private var appForceQuit = false
    private let workspaceNC = NSWorkspace.shared.notificationCenter
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Only initialize if Spotify is already running
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            self.app = SBApplication(bundleIdentifier: bundleIdentifier)
        }
        
        // Observe launches
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.app = SBApplication(bundleIdentifier: self!.bundleIdentifier)
            self?.appForceQuit = false
        }
        
        // Observe quits
        workspaceNC.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.appForceQuit = true
            self?.app = nil
        }
    }
    
    deinit {
        workspaceNC.removeObserver(self)
    }
    
    var playerPosition: Double? {
        app?.playerPosition
    }
    
    var isPlaying: Bool {
        guard let a = app, !appForceQuit else { return false }
        return a.playerState == .playing
    }
    
    var volume: CGFloat {
        CGFloat(app?.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard !appForceQuit, let a = app else {
            completion(nil); return
        }
        guard let track = a.currentTrack else {
            completion(nil); return
        }
        
        let title = track.name ?? "Unknown Title"
        let artist = track.artist ?? "Unknown Artist"
        let album = track.album ?? "Unknown Album"
        let duration = Double(track.duration ?? 0) / 1000.0
        let elapsed  = a.playerPosition ?? 0
        let playing  = a.playerState == .playing
        
        // fetch artwork from URL if present
        if let urlString = track.artworkUrl, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data,_,_ in
                var art: NSImage? = nil
                if let d=data, let img=NSImage(data:d) { art=img }
                let info = NowPlayingInfo(
                    title: title, artist: artist, album: album,
                    duration: duration, elapsedTime: elapsed,
                    isPlaying: playing, artwork: art, appName: self.appName
                )
                DispatchQueue.main.async { completion(info) }
            }.resume()
        } else {
            let info = NowPlayingInfo(
                title: title, artist: artist, album: album,
                duration: duration, elapsedTime: elapsed,
                isPlaying: playing, artwork: nil, appName: appName
            )
            completion(info)
        }
    }
    
    func playPause()    { app?.playpause?() }
    func previousTrack(){ app?.previousTrack?() }
    func nextTrack()    { app?.nextTrack?() }
    func seekTo(time: TimeInterval) {
        app?.setPlayerPosition?(time)
    }
    func setVolume(volume: Int) {
        app?.setSoundVolume?(volume)
    }
    func isAppRunning() -> Bool {
        let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
        if !running {
            appForceQuit = true
            app = nil
        }
        return running
    }
}
