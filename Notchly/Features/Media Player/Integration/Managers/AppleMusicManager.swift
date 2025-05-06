//
//  AppleMusicManager.swift
//  Notchly
//
//  Created by Mason Blumling on 2025-03-XX.
//

import Foundation
import AppKit
import ScriptingBridge
import Combine

// MARK: - Apple Music ScriptingBridge Protocols

/// Apple Music track properties exposed via ScriptingBridge
@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }
    @objc optional func artworks() -> [Any]
}

/// Apple Music app scripting interface
@objc protocol AppleMusicApp {
    @objc optional var playerState: Int { get }
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: AppleMusicTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional var soundVolume: Int { get }
}

/// Allow SBApplication to conform to AppleMusicApp
extension SBApplication: AppleMusicApp {}

/// Apple Music media adapter that conforms to PlayerProtocol.
/// Uses ScriptingBridge with caching to avoid flicker and reduce CPU overhead.
final class AppleMusicManager: PlayerProtocol, SBApplicationDelegate {
    
    // MARK: - PlayerProtocol Properties

    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }

    // MARK: - Internal State

    private var cachedPlayState: Bool?
    private var cachedTrackInfo: NowPlayingInfo?
    private var lastStateCheckTime: Date?
    private let cacheTimeout: TimeInterval = 0.1

    private var app: AppleMusicApp?
    private let workspaceNC = NSWorkspace.shared.notificationCenter

    // MARK: - Initialization

    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject

        /// Attach immediately if app is already running
        if checkRunning() {
            attachToRunningApp()
        }

        /// Observe app launches
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.attachToRunningApp()
        }

        /// Observe app terminations
        workspaceNC.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.app = nil
            self?.clearCache()
        }
    }

    deinit {
        workspaceNC.removeObserver(self)
    }

    // MARK: - SBApplication Delegate

    func applicationShouldLaunch(_ sender: SBApplication!) -> Bool {
        return false
    }

    func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
        return nil
    }

    // MARK: - App Connection

    private func attachToRunningApp() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
              let sb = SBApplication(processIdentifier: running.processIdentifier) as? (SBApplication & AppleMusicApp) else { return }
        sb.delegate = self
        self.app = sb
    }

    private func checkRunning() -> Bool {
        let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        if !isRunning {
            app = nil
            clearCache()
        }
        return isRunning
    }

    // MARK: - Cache Management

    private func clearCache() {
        cachedPlayState = nil
        cachedTrackInfo = nil
        lastStateCheckTime = nil
    }

    private func cacheIsValid() -> Bool {
        guard let last = lastStateCheckTime else { return false }
        return Date().timeIntervalSince(last) < cacheTimeout
    }

    // MARK: - PlayerProtocol Implementation

    func isAppRunning() -> Bool {
        return checkRunning()
    }

    var playerPosition: Double? {
        guard checkRunning(), let a = app else { return nil }
        return a.playerPosition
    }

    var isPlaying: Bool {
        if cacheIsValid(), let cached = cachedPlayState {
            return cached
        }

        guard checkRunning(), let a = app else { return false }

        /// Apple Music's `playerState` value for "playing" is 1800426320
        let actualState = a.playerState == 1800426320
        cachedPlayState = actualState
        lastStateCheckTime = Date()
        return actualState
    }

    var volume: CGFloat {
        guard checkRunning(), let a = app else { return 0 }
        return CGFloat(a.soundVolume ?? 50)
    }

    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        if cacheIsValid(), let cached = cachedTrackInfo {
            /// Use updated position but keep other cached metadata
            let elapsed = app?.playerPosition ?? cached.elapsedTime
            completion(cached.copy(withElapsed: elapsed, isPlaying: isPlaying))
            return
        }

        guard checkRunning(), let a = app, let track = a.currentTrack else {
            clearCache()
            return completion(nil)
        }

        let playing = isPlaying
        let elapsed = a.playerPosition ?? 0
        let duration = track.duration

        var artwork: NSImage? = nil
        if let arts = track.artworks?(),
           let first = arts.first as? MusicArtwork,
           let img = first.data {
            artwork = img
        }

        let info = NowPlayingInfo(
            title: track.name,
            artist: track.artist,
            album: track.album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: playing,
            artwork: artwork,
            appName: appName
        )

        cachedTrackInfo = info
        lastStateCheckTime = Date()
        completion(info)
    }

    func playPause() {
        guard checkRunning(), let a = app else { return }

        let wasPlaying = isPlaying
        cachedPlayState = !wasPlaying
        lastStateCheckTime = Date()

        a.playpause?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.cachedPlayState = nil
            _ = self?.isPlaying
        }
    }

    func previousTrack() {
        guard checkRunning(), let a = app else { return }
        clearCache()
        a.backTrack?()
    }

    func nextTrack() {
        guard checkRunning(), let a = app else { return }
        clearCache()
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

// MARK: - NowPlayingInfo Convenience

private extension NowPlayingInfo {
    /// Copies this info while updating the elapsed time and play state
    func copy(withElapsed newTime: TimeInterval, isPlaying: Bool) -> NowPlayingInfo {
        NowPlayingInfo(
            title: self.title,
            artist: self.artist,
            album: self.album,
            duration: self.duration,
            elapsedTime: newTime,
            isPlaying: isPlaying,
            artwork: self.artwork,
            appName: self.appName
        )
    }
}
