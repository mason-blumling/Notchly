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

// MARK: – Apple Music ScriptingBridge Protocols

@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }
    @objc optional func artworks() -> [Any]
}

@objc protocol AppleMusicApp {
    @objc optional var playerState: Int { get }
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: AppleMusicTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional var soundVolume: Int { get }
}

extension SBApplication: AppleMusicApp {}

/// A PlayerProtocol adapter for Apple Music with state caching to prevent flicker
final class AppleMusicManager: PlayerProtocol, SBApplicationDelegate {
    
    // MARK: PlayerProtocol
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }

    // MARK: State Cache
    private var cachedPlayState: Bool?
    private var cachedTrackInfo: NowPlayingInfo?
    private var lastStateCheckTime: Date?
    private let cacheTimeout: TimeInterval = 0.1

    // MARK: Internal
    private var app: AppleMusicApp?
    private let workspaceNC = NSWorkspace.shared.notificationCenter

    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Attach if already running
        if checkRunning() {
            attachToRunningApp()
        }
        
        // Watch for launches
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.attachToRunningApp()
        }
        
        // Watch for quits
        workspaceNC.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
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

    private func attachToRunningApp() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else { return }
        
        let sb = SBApplication(processIdentifier: running.processIdentifier)
        as? (SBApplication & AppleMusicApp)
        sb?.delegate = self
        self.app = sb
    }
    
    private func checkRunning() -> Bool {
        let running = !NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .isEmpty
        if !running {
            app = nil
            clearCache()
        }
        return running
    }

    // MARK: – Cache Management
    
    private func clearCache() {
        cachedPlayState = nil
        cachedTrackInfo = nil
        lastStateCheckTime = nil
    }

    private func cacheIsValid() -> Bool {
        guard let lastCheck = lastStateCheckTime else { return false }
        return Date().timeIntervalSince(lastCheck) < cacheTimeout
    }

    // MARK: – SBApplicationDelegate

    func applicationShouldLaunch(_ sender: SBApplication!) -> Bool {
        return false
    }

    func eventDidFail(
        _ event: UnsafePointer<AppleEvent>,
        withError error: Error
    ) -> Any? {
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
        // Return cached state if valid
        if cacheIsValid(), let cached = cachedPlayState {
            return cached
        }
        
        guard checkRunning(), let a = app else { return false }
        let actualState = a.playerState == 1800426320
        
        // Update cache
        cachedPlayState = actualState
        lastStateCheckTime = Date()
        
        return actualState
    }
    
    var volume: CGFloat {
        guard checkRunning(), let a = app else { return 0 }
        return CGFloat(a.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        // Return cached info if still playing the same track
        if cacheIsValid(), let cached = cachedTrackInfo {
            // Update elapsed time but keep rest cached
            if let a = app {
                let updatedInfo = NowPlayingInfo(
                    title: cached.title,
                    artist: cached.artist,
                    album: cached.album,
                    duration: cached.duration,
                    elapsedTime: a.playerPosition ?? cached.elapsedTime,
                    isPlaying: self.isPlaying,
                    artwork: cached.artwork,
                    appName: cached.appName
                )
                completion(updatedInfo)
                return
            }
        }
        
        guard checkRunning(), let a = app, let track = a.currentTrack else {
            clearCache()
            return completion(nil)
        }
        
        let playing = self.isPlaying
        let elapsed = a.playerPosition ?? 0
        let duration = track.duration
        
        var artwork: NSImage? = nil
        
        if let arts = track.artworks?() {
            if let first = arts.first as? MusicArtwork {
                if let img = first.data, img.isKind(of: NSImage.self) {
                    artwork = img
                }
            }
        }

        let info = NowPlayingInfo(
            title:       track.name,
            artist:      track.artist,
            album:       track.album,
            duration:    duration,
            elapsedTime: elapsed,
            isPlaying:   playing,
            artwork:     artwork,
            appName:     appName
        )
        
        // Cache the track info
        cachedTrackInfo = info
        lastStateCheckTime = Date()
        
        completion(info)
    }
    
    func playPause() {
        guard checkRunning(), let a = app else { return }
        
        // Optimistically update cache
        let wasPlaying = self.isPlaying
        cachedPlayState = !wasPlaying
        lastStateCheckTime = Date()
        
        a.playpause?()
        
        // Verify state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.cachedPlayState = nil  // Force fresh check
            _ = self?.isPlaying
        }
    }
    
    func previousTrack() {
        guard checkRunning(), let a = app else { return }
        clearCache()  // Clear cache as track will change
        a.backTrack?()
    }
    
    func nextTrack() {
        guard checkRunning(), let a = app else { return }
        clearCache()  // Clear cache as track will change
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
