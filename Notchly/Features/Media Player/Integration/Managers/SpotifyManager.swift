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

/// A PlayerProtocol adapter for Spotify that only attaches if already running.
/// Avoids auto-launching the app using SBApplication.
final class SpotifyManager: PlayerProtocol, SBApplicationDelegate {
    
    // MARK: - PlayerProtocol Conformance

    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Spotify" }
    var appPath: URL { URL(fileURLWithPath: "/Applications/Spotify.app") }
    var appNotification: String { "\(bundleIdentifier).PlaybackStateChanged" }
    var bundleIdentifier: String { Constants.Spotify.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }

    // MARK: - Internal State

    private var app: SpotifyApplication?
    private let workspaceNC = NSWorkspace.shared.notificationCenter

    // MARK: - Initialization

    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject

        /// Attach immediately if already running
        if checkRunning() {
            attachToRunningApp()
        }

        /// Observe app launch
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.attachToRunningApp()
        }

        /// Observe app termination
        workspaceNC.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.app = nil
        }
    }

    deinit {
        workspaceNC.removeObserver(self)
    }

    // MARK: - SBApplicationDelegate

    func applicationShouldLaunch(_ sender: SBApplication!) -> Bool {
        return false
    }

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
        return nil
    }

    // MARK: - App Attachment

    private func attachToRunningApp() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
              let sb = SBApplication(processIdentifier: running.processIdentifier) as? (SBApplication & SpotifyApplication)
        else { return }

        sb.delegate = self
        self.app = sb
    }

    private func checkRunning() -> Bool {
        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        if !isRunning { app = nil }
        return isRunning
    }

    // MARK: - PlayerProtocol Properties & Methods

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

        /// Load artwork image asynchronously
        if let urlStr = track.artworkUrl, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                var art: NSImage? = nil
                if let d = data, let img = NSImage(data: d) {
                    art = img
                }
                DispatchQueue.main.async {
                    completion(NowPlayingInfo(
                        title:       title,
                        artist:      artist,
                        album:       album,
                        duration:    duration,
                        elapsedTime: elapsed,
                        isPlaying:   playing,
                        artwork:     art,
                        appName:     self.appName
                    ))
                }
            }.resume()
        } else {
            completion(NowPlayingInfo(
                title:       title,
                artist:      artist,
                album:       album,
                duration:    duration,
                elapsedTime: elapsed,
                isPlaying:   playing,
                artwork:     nil,
                appName:     appName
            ))
        }
    }

    func playPause() {
        guard checkRunning(), let a = app else { return }
        a.playpause?()
    }

    func previousTrack() {
        guard checkRunning(), let a = app else { return }
        a.previousTrack?()
    }

    func nextTrack() {
        guard checkRunning(), let a = app else { return }
        a.nextTrack?()
    }

    func seekTo(time: TimeInterval) {
        guard checkRunning(), let sb = app as? SBObject else { return }
        sb.setValue(time, forKey: "playerPosition")
    }

    func setVolume(volume: Int) {
        guard checkRunning(), let sb = app as? SBObject else { return }
        sb.setValue(volume, forKey: "soundVolume")
    }
}
