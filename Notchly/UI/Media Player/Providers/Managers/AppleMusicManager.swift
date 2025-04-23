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

/// A PlayerProtocol adapter for Apple Music that never auto-launches the app.
final class AppleMusicManager: PlayerProtocol, SBApplicationDelegate {
    
    // MARK: PlayerProtocol
    var notificationSubject: PassthroughSubject<AlertItem, Never>
    var appName: String { "Apple Music" }
    var appPath: URL { URL(fileURLWithPath: "/System/Applications/Music.app") }
    var appNotification: String { "\(bundleIdentifier).playerInfo" }
    var bundleIdentifier: String { Constants.AppleMusic.bundleID }
    var defaultAlbumArt: NSImage { NSImage(named: "DefaultAlbumArt") ?? NSImage() }

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
        }
    }

    deinit {
        workspaceNC.removeObserver(self)
    }

   /// Only attach to the already-running Music process (never auto-launch).
    private func attachToRunningApp() {
        guard let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else { return }
        
        // use the public SBApplication(processIdentifier:) initializer
        let sb = SBApplication(processIdentifier: running.processIdentifier)
        as? (SBApplication & AppleMusicApp)
        sb?.delegate = self
        self.app = sb
    }
    
    /// Return true if Music is running; clear `app` if not.
    private func checkRunning() -> Bool {
        let running = !NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .isEmpty
        if !running { app = nil }
        return running
    }

    // MARK: – SBApplicationDelegate (prevent auto-launch)

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
        guard checkRunning(), let a = app else { return false }
        return a.playerState == 1800426320
    }
    
    var volume: CGFloat {
        guard checkRunning(), let a = app else { return 0 }
        return CGFloat(a.soundVolume ?? 50)
    }
    
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard checkRunning(), let a = app, let track = a.currentTrack else {
            return completion(nil)
        }
        let playing  = (a.playerState ?? 0) == 1800426320
        let elapsed  = a.playerPosition ?? 0
        let duration = track.duration
        
        var artwork: NSImage? = nil
        if let arts = track.artworks?(),
           let first = arts.first as? MusicArtwork,
           let img = first.data, img.size != .zero {
            artwork = img
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
        completion(info)
    }
    
    func playPause() {
        guard checkRunning(), let a = app else { return }
        a.playpause?()
    }
    func previousTrack() {
        guard checkRunning(), let a = app else { return }
        a.backTrack?()
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
