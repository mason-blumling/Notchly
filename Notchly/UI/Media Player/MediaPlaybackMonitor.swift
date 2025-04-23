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
/// Publishes:
///  • `currentTime` & `duration` for your existing scrubber API,
///  • `progress` & `displayTimes` for perfectly lock-stepped labels + bar,
/// and **only** polls when expanded (relying on DistributedNotifications when collapsed).
@MainActor
final class MediaPlaybackMonitor: ObservableObject {

    // MARK: Published (for your existing views)
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = ""

    /// Time, in seconds, into the track (for TrackScrubberView).
    @Published var currentTime: TimeInterval = 0
    /// Full track duration (for TrackScrubberView).
    @Published var duration: TimeInterval = 1

    /// Normalized 0…1 progress (for any future bar/handle).
    @Published var progress: CGFloat = 0
    /// Formatted elapsed/remaining strings, updated atomically.
    @Published var displayTimes: (elapsed: String, remaining: String) = ("0:00", "-0:00")

    /// When true, we’re dragging and should pause interpolation.
    @Published var isScrubbing: Bool = false
    
    @objc private func musicDidPost(_ note: Notification) {
      updateMediaState()
    }
    @objc private func spotifyDidPost(_ note: Notification) {
      updateMediaState()
    }
    @objc private func workspaceDidTerminate(_ note: Notification) {
      if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
         app.bundleIdentifier == Constants.AppleMusic.bundleID {
        clearMediaState()
      }
    }

    // MARK: private state
    private var baseElapsed: TimeInterval = 0
    private var lastUpdateTimestamp: Date = .now
    private var lastValidDuration: TimeInterval = 0
    private var expectedPlayState: Bool? = nil
    private var expectedStateTimestamp: Date? = nil
    private var isToggledManually = false

    private var metadataPoller: AnyCancellable?
    private var interpolationTimer: Timer?

    private let provider: MediaPlayerAppProvider
    private let distCenter = DistributedNotificationCenter.default()

    /// Poll every 2 s when expanded
    private let expandedInterval: TimeInterval = 2

    init() {
        provider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject())
        setupNotifications()
        // start collapsed: no polling until setExpanded(true)
    }

    deinit {
        metadataPoller?.cancel()
        interpolationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        distCenter.removeObserver(self)
    }

    // MARK: — Expand / Collapse

    /// Call this whenever the notch expands (true) or collapses (false).
    func setExpanded(_ expanded: Bool) {
        metadataPoller?.cancel()
        interpolationTimer?.invalidate()

        guard expanded else {
            // stop polling/interp—rely solely on notifications
            return
        }

        // 1) immediate metadata fetch
        updateMediaState()

        // 2) poll every 2 s
        metadataPoller = Timer.publish(every: expandedInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateMediaState() }

        // 3) after a tiny delay, start 30 Hz interpolation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.interpolationTimer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
                guard let s = self,
                      s.isPlaying,
                      !s.isScrubbing,
                      let dur = s.nowPlaying?.duration,
                      dur > 0 else { return }

                let now = Date()
                let elapsed = s.baseElapsed + now.timeIntervalSince(s.lastUpdateTimestamp)
                let clamped = min(max(0, elapsed), dur)
                let ratio = CGFloat(clamped / dur)

                // atomic update of both your scrubber inputs
                s.currentTime = clamped
                s.duration    = dur
                s.progress    = ratio
                s.displayTimes = (
                    elapsed:   Self.formatTime(clamped),
                    remaining: "-\(Self.formatTime(dur - clamped))"
                )
            }
        }
    }

    // MARK: — Distributed Notifications

    private func setupNotifications() {
        // Listen for SBApplication distributed notifications by selector
        distCenter.addObserver(
            self,
            selector: #selector(musicDidPost(_:)),
            name: .init("com.apple.Music.playerInfo"),
            object: nil
        )
        distCenter.addObserver(
            self,
            selector: #selector(spotifyDidPost(_:)),
            name: .init("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        // Tear down state when Music quits
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(workspaceDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    // MARK: — Fetch & Publish

    /// Core logic: ask the provider for `NowPlayingInfo` and publish all fields in lock-step.
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
                    s.clearMediaState()
                    return
                }

                // duration fallback
                var dur = info.duration
                if dur <= 1.0, s.lastValidDuration > 1.0 {
                    dur = s.lastValidDuration
                } else {
                    s.lastValidDuration = dur
                }

                // play-state enforcement
                let playing = info.isPlaying
                if let exp = s.expectedPlayState,
                   let ts  = s.expectedStateTimestamp,
                   Date().timeIntervalSince(ts) < 1.5 {
                    s.isPlaying = exp
                } else {
                    s.expectedPlayState = nil
                    s.expectedStateTimestamp = nil
                    s.isPlaying = playing
                }

                // re-baseline for interpolation
                if !s.isScrubbing {
                    s.baseElapsed        = max(0, min(info.elapsedTime, dur))
                    s.lastUpdateTimestamp = Date()
                }

                // publish unified model
                s.nowPlaying = info

                // atomic metadata update
                let elapsed = s.baseElapsed
                let ratio   = CGFloat(elapsed / dur)
                s.currentTime  = elapsed
                s.duration     = dur
                s.progress     = ratio
                s.displayTimes = (
                    elapsed:   Self.formatTime(elapsed),
                    remaining: "-\(Self.formatTime(dur - elapsed))"
                )
            }
        }
    }

    // MARK: — Controls

    func previousTrack() { provider.getActivePlayer()?.previousTrack(); updateMediaState() }
    func nextTrack()     { provider.getActivePlayer()?.nextTrack();     updateMediaState() }

    func togglePlayPause() {
        guard let p = provider.getActivePlayer() else { return }
        let newState = !isPlaying
        expectedPlayState      = newState
        expectedStateTimestamp = Date()
        isToggledManually      = true
        isPlaying              = newState
        p.playPause()
        DispatchQueue.main.async {
            self.updateMediaState()
            self.isToggledManually = false
        }
    }

    func seekTo(time: TimeInterval) {
        provider.getActivePlayer()?.seekTo(time: time)
        // reseed interpolation if already expanded
        DispatchQueue.main.async { self.setExpanded(true) }
    }

    // MARK: — Clear

    private func clearMediaState() {
        isPlaying             = false
        nowPlaying            = nil
        currentTime           = 0
        duration              = 1
        progress              = 0
        displayTimes          = ("0:00", "-0:00")
        baseElapsed           = 0
        lastValidDuration     = 0
        expectedPlayState     = nil
        expectedStateTimestamp = nil
        isToggledManually     = false
    }

    // MARK: — Helpers

    private static func formatTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
