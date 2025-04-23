//
//  AppleMusicManager.swift
//  Notchly
//
//  Created by Mason Blumling on 2025-03-XX.
//

import Foundation
import AppKit
import ScriptingBridge
import SwiftUI
import Combine

// MARK: - Apple Music Scripting Protocols

/// Represents a track in the Apple Music app.
@objc protocol AppleMusicTrack {
    var name: String { get }
    var artist: String { get }
    var album: String { get }
    var duration: Double { get }
    @objc optional func artworks() -> [Any]
}

/// Represents the Apple Music application.
@objc protocol AppleMusicApp {
    @objc optional var isRunning: Bool { get }
    @objc optional var playerState: Int { get }
    @objc optional var playerPosition: Double { get set }
    @objc optional var currentTrack: AppleMusicTrack { get }
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional var soundVolume: Int { get }
}

/// Extend SBApplication so that it conforms to AppleMusicApp.
extension SBApplication: AppleMusicApp {}

// MARK: - AppleMusicManager Implementation

/// An implementation of PlayerProtocol for Apple Music using ScriptingBridge.
final class AppleMusicManager: PlayerProtocol {
    
    // MARK: - PlayerProtocol
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }
    
    // MARK: - Internal
    private var app: AppleMusicApp?
    private var appForceQuit = false
    private let workspaceNC = NSWorkspace.shared.notificationCenter

    init(notificationSubject: PassthroughSubject<AlertItem, Never>) {
        self.notificationSubject = notificationSubject
        
        // Only instantiate if Music is already running
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }) {
            self.app = SBApplication(bundleIdentifier: bundleIdentifier)
            self.appForceQuit = false
        }
        
        // Watch for Music launches
        workspaceNC.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  info.bundleIdentifier == self?.bundleIdentifier else { return }
            self?.app = SBApplication(bundleIdentifier: self!.bundleIdentifier)
            self?.appForceQuit = false
        }
        
        // Watch for Music quits
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
        return a.playerState == 1800426320
    }
    
    var volume: CGFloat {
        CGFloat(app?.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard !appForceQuit, let app = app else {
            completion(nil)
            return
        }
        guard let track = app.currentTrack else {
            completion(nil)
            return
        }
        
        let playingState = app.playerState ?? 0
        let currentlyPlaying = (playingState == 1800426320)
        let elapsedTime = app.playerPosition ?? 0.0
        let duration = track.duration
        
        var artwork: NSImage? = nil
        if let arts = track.artworks?(), let first = arts.first as? MusicArtwork,
           let img = first.data, img.size != .zero {
            artwork = img
        }
        
        let info = NowPlayingInfo(
            title: track.name,
            artist: track.artist,
            album: track.album,
            duration: duration,
            elapsedTime: elapsedTime,
            isPlaying: currentlyPlaying,
            artwork: artwork,
            appName: appName
        )
        completion(info)
    }
    
    func playPause() { app?.playpause?() }
    func previousTrack() { app?.backTrack?() }
    func nextTrack()     { app?.nextTrack?() }
    func seekTo(time: TimeInterval) {
        (app as? SBObject)?.setValue(time, forKey: "playerPosition")
    }
    func setVolume(volume: Int) {
        (app as? SBObject)?.setValue(volume, forKey: "soundVolume")
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
