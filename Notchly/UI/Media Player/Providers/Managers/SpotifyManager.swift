//
//  SpotifyManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import Combine
import Foundation
import AppKit
import ScriptingBridge

/// A PlayerProtocol adapter for Spotify that never auto-launches the app.
final class SpotifyManager: PlayerProtocol, SBApplicationDelegate {
    
    // MARK: PlayerProtocol
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Spotify" }
    var appPath: URL { URL(fileURLWithPath: "/Applications/Spotify.app") }
    var appNotification: String { "\(bundleIdentifier).PlaybackStateChanged" }
    var bundleIdentifier: String { Constants.Spotify.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // MARK: Internal
    private var app: SpotifyApplication?
    private let workspaceNC = NSWorkspace.shared.notificationCenter
    
    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Attach if already running
        if checkRunning() {
            attachToRunningApp()
        }
        
        // Observe launches
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.attachToRunningApp()
        }
        
        // Observe quits
        workspaceNC.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.app = nil
        }
    }
    
    deinit {
        workspaceNC.removeObserver(self)
    }
    
    /// Only attach to the already-running Spotify process (never auto-launch).
    private func attachToRunningApp() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else { return }

        // use the public SBApplication(processIdentifier:) initializer
        let sb = SBApplication(processIdentifier: running.processIdentifier)
                  as? (SBApplication & SpotifyApplication)
        sb?.delegate = self
        self.app = sb
    }
    
    /// Returns true if Spotify is running; clears `app` if not.
    private func checkRunning() -> Bool {
        let running = !NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .isEmpty
        if !running { app = nil }
        return running
    }
    
    // MARK: – SBApplicationDelegate
    
    /// Prevent any auto-launch by ScriptingBridge
    func applicationShouldLaunch(_ sender: SBApplication!) -> Bool {
        return false
    }
    
    /// Swallow AppleEvent failures
    func eventDidFail(_ event: UnsafePointer<AppleEvent>!, withError error: Error!) -> Any? {
        return nil
    }
    
    // MARK: – PlayerProtocol
    
    func isAppRunning() -> Bool {
        return checkRunning()
    }
    
    var playerPosition: Double? {
        guard checkRunning(), let a = app else { return nil }
        return a.playerPosition
    }
    
    var isPlaying: Bool {
        guard checkRunning(), let a = app else { return false }
        return a.playerState == .playing
    }
    
    var volume: CGFloat {
        guard checkRunning(), let a = app else { return 0 }
        return CGFloat(a.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard checkRunning(), let a = app, let track = a.currentTrack else {
            return completion(nil)
        }
        
        let title    = track.name    ?? "Unknown Title"
        let artist   = track.artist  ?? "Unknown Artist"
        let album    = track.album   ?? "Unknown Album"
        let duration = Double(track.duration ?? 0) / 1000
        let elapsed  = a.playerPosition ?? 0
        let playing  = a.playerState == .playing
        
        if let urlStr = track.artworkUrl, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data,_,_ in
                var art: NSImage? = nil
                if let d = data, let img = NSImage(data: d) { art = img }
                
                DispatchQueue.main.async {
                    let info = NowPlayingInfo(
                        title:       title,
                        artist:      artist,
                        album:       album,
                        duration:    duration,
                        elapsedTime: elapsed,
                        isPlaying:   playing,
                        artwork:     art,
                        appName:     self.appName
                    )
                    completion(info)
                }
            }.resume()
        } else {
            let info = NowPlayingInfo(
                title:       title,
                artist:      artist,
                album:       album,
                duration:    duration,
                elapsedTime: elapsed,
                isPlaying:   playing,
                artwork:     nil,
                appName:     appName
            )
            completion(info)
        }
    }
    
    func playPause()       { guard checkRunning(), let a = app else { return }; a.playpause?() }
    func previousTrack()   { guard checkRunning(), let a = app else { return }; a.previousTrack?() }
    func nextTrack()       { guard checkRunning(), let a = app else { return }; a.nextTrack?() }
    func seekTo(time: TimeInterval) {
        guard checkRunning(), let sb = app as? SBObject else { return }
        sb.setValue(time, forKey: "playerPosition")
    }
    func setVolume(volume: Int) {
        guard checkRunning(), let sb = app as? SBObject else { return }
        sb.setValue(volume, forKey: "soundVolume")
    }
}
