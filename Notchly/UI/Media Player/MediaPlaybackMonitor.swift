//
//  MediaPlaybackMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import SwiftUI
import Combine
import AppKit

/// Monitors media playback state using a unified media provider (PlayerProtocol).
/// This class polls the active media player (via MediaPlayerAppProvider) and updates published
/// properties (like nowPlaying, isPlaying, currentTime, etc.) so the UI can reflect the current state.
@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    
    // MARK: Published
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = ""
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    /// A tuple holding formatted strings for elapsed and remaining time, updated in lockstep.
    @Published var displayTimes: (elapsed: String, remaining: String) = ("0:00", "-0:00")
    
    // MARK: Private
    private var baseElapsed: TimeInterval = 0
    private var lastUpdateTimestamp: Date = .now
    private var lastValidDuration: TimeInterval = 0
    private var expectedPlayState: Bool? = nil
    private var expectedStateTimestamp: Date? = nil
    private var isToggledManually = false
    
    private var metadataPoller: AnyCancellable?
    private var interpolationTimer: Timer?
    
    private let provider: MediaPlayerAppProvider
    private let notificationSubject = PassthroughSubject<AlertItem, Never>()
    private let distCenter = DistributedNotificationCenter.default()
    
    // Polling intervals
    private let expandedInterval: TimeInterval = 2
    private let collapsedInterval: TimeInterval = 10
    
    // MARK: Init
    init() {
        provider = MediaPlayerAppProvider(notificationSubject: notificationSubject)
        setupNotifications()
        setExpanded(false) // start collapsed
    }
    
    deinit {
        metadataPoller?.cancel()
        interpolationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Mode Switch
    /// Call this whenever the notch expands/collapses.
    @MainActor
    func setExpanded(_ expanded: Bool) {
        metadataPoller?.cancel()
        interpolationTimer?.invalidate()
        
        // Fire one now so baseElapsed/lastUpdateTimestamp are fresh
        updateMediaState()
        
        guard expanded else {
            // no poll or interp when collapsed; rely on DNC notifications
            return
        }
        
        // 1) poll metadata every 2s
        metadataPoller = Timer.publish(every: expandedInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateMediaState() }
        
        // 2) after a tiny lag, spin up 30Hz interp for the scrubber
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.interpolationTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let s = self, s.isPlaying, !s.isScrubbing else { return }
                    
                    // Compute elapsed + remaining
                    let now = Date()
                    let elapsed = s.baseElapsed + now.timeIntervalSince(s.lastUpdateTimestamp)
                    let remaining = max(0, s.duration - elapsed)
                    
                    // Update both values in one atomic step
                    s.currentTime = elapsed
                    s.displayTimes = (
                        elapsed:   Self.formatTime(elapsed),
                        remaining: "-\(Self.formatTime(remaining))"
                    )
                }
            }
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        distCenter.addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateMediaState() }
        
        distCenter.addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateMediaState() }
        
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.bundleIdentifier == Constants.AppleMusic.bundleID {
                self?.clearMediaState()
            }
        }
    }
    
    // MARK: - State Update
    func updateMediaState() {
        guard let player = provider.getActivePlayer(), player.isAppRunning() else {
            clearMediaState()
            return
        }
        
        activePlayerName = player.appName
        if isToggledManually { return }
        
        player.getNowPlayingInfo { [weak self] info in
            guard let s = self else { return }
            DispatchQueue.main.async {
                guard let info = info, !info.title.isEmpty else {
                    if let last = s.expectedStateTimestamp,
                       Date().timeIntervalSince(last) > 3 {
                        s.clearMediaState()
                    }
                    return
                }
                
                // Duration fallback
                var validDur = info.duration
                if validDur <= 1.0, s.lastValidDuration > 1.0 {
                    validDur = s.lastValidDuration
                } else {
                    s.lastValidDuration = validDur
                }
                
                // Play state enforcement
                let newState = info.isPlaying
                if let exp = s.expectedPlayState,
                   let ts = s.expectedStateTimestamp,
                   Date().timeIntervalSince(ts) < 1.5 {
                    s.isPlaying = exp
                } else {
                    s.expectedPlayState = nil
                    s.expectedStateTimestamp = nil
                    if s.isPlaying != newState {
                        s.isPlaying = newState
                    }
                }
                
                // Update timing
                if !s.isScrubbing {
                    s.baseElapsed = max(0, min(info.elapsedTime, validDur))
                    s.lastUpdateTimestamp = Date()
                }
                
                // Publish nowPlaying
                s.nowPlaying = NowPlayingInfo(
                    title:       info.title,
                    artist:      info.artist,
                    album:       info.album,
                    duration:    validDur,
                    elapsedTime: s.isScrubbing ? s.currentTime : s.baseElapsed,
                    isPlaying:   newState,
                    artwork:     info.artwork,
                    appName:     info.appName
                )
                
                // Update duration & currentTime
                s.duration    = validDur
                s.currentTime = s.nowPlaying!.elapsedTime
                
                // And atomically update both display labels
                let elapsed   = s.currentTime
                let remaining = max(0, validDur - elapsed)
                s.displayTimes = (
                    elapsed:   Self.formatTime(elapsed),
                    remaining: "-\(Self.formatTime(remaining))"
                )
            }
        }
    }
    
    // MARK: - Controls
    func previousTrack() { provider.getActivePlayer()?.previousTrack(); updateMediaState() }
    func nextTrack()     { provider.getActivePlayer()?.nextTrack();     updateMediaState() }
    
    func togglePlayPause() {
        guard let p = provider.getActivePlayer() else { return }
        let newState = !isPlaying
        expectedPlayState = newState
        expectedStateTimestamp = Date()
        isToggledManually = true
        isPlaying = newState
        p.playPause()
        DispatchQueue.main.async {
            self.updateMediaState()
            self.isToggledManually = false
        }
    }
    
    func seekTo(time: TimeInterval) {
        provider.getActivePlayer()?.seekTo(time: time)
        currentTime = time
        updateMediaState()
    }
    
    // MARK: - Clear
    private func clearMediaState() {
        isPlaying = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nowPlaying     = nil
            self.currentTime    = 0
            self.lastValidDuration = 0
            self.activePlayerName  = ""
            self.displayTimes      = ("0:00", "-0:00")
        }
    }
    
    // MARK: - Time Formatting Helper
    private static func formatTime(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let minutes      = totalSeconds / 60
        let seconds      = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
