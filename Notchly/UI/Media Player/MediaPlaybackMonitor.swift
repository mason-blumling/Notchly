//
//  MediaPlaybackMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import SwiftUI
import Combine
import AppKit
import ScriptingBridge

/// Monitors media playback state using Apple's private MediaRemote framework.
/// It listens for system notifications and uses multiple polling timers (fallback, constant, end-of-track, and duration polling)
/// to keep the UI in sync with the media state even if the system data is delayed or bogus.
@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    // MARK: - Singleton Instance
    static let shared = MediaPlaybackMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayer: String = "Unknown"
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var fallbackTimer: Timer?
    private var endPollingTimer: Timer?
    private var constantPollingTimer: Timer?
    private var durationPollingTimer: Timer?
    
    private var lastValidUpdate: Date? = nil
    private var lastValidDuration: TimeInterval = 0
    
    /// Flag to temporarily ignore system updates during a user-initiated toggle.
    private var isToggledManually = false
    /// Expected play state after a user toggle, with timestamp.
    private var expectedPlayState: Bool? = nil
    private var expectedStateTimestamp: Date? = nil
    
    // MARK: - Playback Manager
    private let playbackManager: MediaPlaybackManager = {
        guard let manager = MediaPlaybackManager() else {
            fatalError("Failed to initialize MediaPlaybackManager")
        }
        return manager
    }()
    
    // MARK: - Initialization
    private init() {
        setupObservers()
    }
    
    // MARK: - Observers Setup
    private func setupObservers() {
        let notifications = [
            NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"),
            NSNotification.Name("com.apple.Music.playerInfo"),
            NSNotification.Name("com.spotify.client.PlaybackStateChanged")
        ]
        for name in notifications {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateMediaState()
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Main Update Logic
    /// Queries the system for the latest media info, reconciles it with any expected state,
    /// and updates the published properties.
    func updateMediaState() {
        if isToggledManually {
            print("updateMediaState: Skipped due to manual toggle")
            return
        }
        
        playbackManager.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let info = info, !info.title.isEmpty {
                    print("updateMediaState: Received valid info -> \(info)")
                    
                    // Validate duration: if bogus (≤ 1.0), try to reuse a cached value or retry.
                    var validDuration: TimeInterval = info.duration
                    if info.duration <= 1.0 {
                        if let current = self.nowPlaying, current.title == info.title, self.lastValidDuration > 1.0 {
                            validDuration = self.lastValidDuration
                            print("updateMediaState: Bogus duration received; reusing cached duration \(validDuration)")
                        } else {
                            print("updateMediaState: Bogus duration (\(info.duration)). Retrying in 0.5s...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.updateMediaState()
                            }
                            return
                        }
                    } else {
                        validDuration = info.duration
                        self.lastValidDuration = validDuration
                    }
                    
                    self.duration = max(validDuration, 1)
                    self.activePlayer = info.appName
                    self.lastValidUpdate = Date()
                    
                    // Expected state reconciliation.
                    if let expected = self.expectedPlayState, let ts = self.expectedStateTimestamp {
                        let elapsed = Date().timeIntervalSince(ts)
                        if elapsed < 1.5 {
                            print("updateMediaState: Within expected window (\(elapsed)s), enforcing expected state (\(expected))")
                            self.isPlaying = expected
                        } else {
                            self.expectedPlayState = nil
                            self.expectedStateTimestamp = nil
                            self.isPlaying = info.isPlaying
                            print("updateMediaState: Expected state stale, trusting system state (\(info.isPlaying))")
                        }
                    } else {
                        self.isPlaying = info.isPlaying
                    }
                    
                    self.nowPlaying = info
                    // Only update currentTime if the user isn't scrubbing.
                    if !self.isScrubbing {
                        let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                        self.currentTime = clampedElapsed
                    } else {
                        print("updateMediaState: User is scrubbing, preserving currentTime")
                    }
                    
                    if self.isPlaying {
                        self.cancelFallbackPolling()
                        self.startProgressTimer()
                        print("updateMediaState: Media is playing (enforced state: \(self.isPlaying))")
                    } else {
                        self.stopProgressTimer()
                        print("updateMediaState: Media is paused (enforced state: \(self.isPlaying))")
                    }
                } else {
                    if let lastUpdate = self.lastValidUpdate, Date().timeIntervalSince(lastUpdate) < 3.0 {
                        let elapsed = Date().timeIntervalSince(lastUpdate)
                        print("updateMediaState: Empty info, retaining last valid state (last update \(elapsed)s ago)")
                    } else {
                        print("updateMediaState: Empty info for too long. Clearing state and starting fallback polling.")
                        self.clearMediaState()
                    }
                    self.endPollingTimer?.invalidate()
                    self.endPollingTimer = nil
                    return
                }
                
                // --- End-of-Track Polling ---
                let remainingTime = self.duration - self.currentTime
                let threshold = max(3.0, 0.05 * self.duration) // Poll if remaining time is less than threshold.
                if self.isPlaying && remainingTime < threshold {
                    if self.endPollingTimer == nil {
                        print("updateMediaState: Near end of track (remaining: \(remainingTime)s); starting end-of-track polling")
                        self.endPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                            DispatchQueue.main.async {
                                self?.updateMediaState()
                            }
                        }
                    }
                } else {
                    self.endPollingTimer?.invalidate()
                    self.endPollingTimer = nil
                }
                // --- End-of-Track Polling ---
                
                // --- Constant Polling ---
                if self.isPlaying {
                    self.startConstantPolling()
                } else {
                    self.cancelConstantPolling()
                }
                // --- End Constant Polling ---
            }
        }
    }
    
    // MARK: - Fallback Polling
    /// Polls for media state every 1 second when no valid info is received.
    private func startFallbackPolling() {
        if fallbackTimer != nil { return }
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateMediaState() }
        }
    }
    
    private func cancelFallbackPolling() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    // MARK: - Constant Polling
    /// Constantly polls for media updates every 1 second while media is playing.
    private func startConstantPolling() {
        if constantPollingTimer != nil { return }
        constantPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateMediaState() }
        }
    }
    
    private func cancelConstantPolling() {
        constantPollingTimer?.invalidate()
        constantPollingTimer = nil
    }
    
    // MARK: - Duration Polling
    /// Polls at high frequency (every 0.25s) when bogus duration data is encountered.
    private func startDurationPolling() {
        if durationPollingTimer != nil { return }
        durationPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateMediaState() }
        }
    }
    
    private func cancelDurationPolling() {
        durationPollingTimer?.invalidate()
        durationPollingTimer = nil
    }
    
    // MARK: - Clear State
    /// Clears the current nowPlaying state and starts fallback polling.
    private func clearMediaState() {
        self.nowPlaying = nil
        self.isPlaying = false
        self.currentTime = 0
        self.lastValidUpdate = nil
        self.startFallbackPolling()
    }
    
    // MARK: - Progress Timer
    /// Starts a timer that updates currentTime every 0.1 seconds.
    func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.fetchElapsedTime()
        }
    }
    
    func stopProgressTimer() {
        progressTimer?.invalidate()
    }
    
    /// Fetches elapsed time from the system and updates currentTime (clamped between 0 and duration).
    func fetchElapsedTime() {
        if self.isScrubbing { return }  // Skip update while user is dragging.
        playbackManager.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info, self.isPlaying else { return }
            DispatchQueue.main.async {
                let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                self.currentTime = clampedElapsed
            }
        }
    }
    
    // MARK: - Playback Actions
    /// Sends a previous track command and forces multiple state updates.
    func previousTrack() {
        playbackManager.previousTrack()
        DispatchQueue.main.async { self.updateMediaState() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateMediaState() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.updateMediaState() }
    }
    
    /// Sends a next track command and forces multiple state updates.
    func nextTrack() {
        playbackManager.nextTrack()
        DispatchQueue.main.async { self.updateMediaState() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateMediaState() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.updateMediaState() }
    }
    
    /// Toggles play/pause, stores the expected state, and schedules updates.
    func togglePlayPause() {
        let newState = !self.isPlaying
        self.expectedPlayState = newState
        self.expectedStateTimestamp = Date()
        
        self.isToggledManually = true
        self.isPlaying = newState  // Immediate UI update.
        playbackManager.togglePlayPause(isPlaying: newState)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMediaState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            self.isToggledManually = false
            self.updateMediaState()
        }
    }
    
    /// Seeks to a specified time in the current track and triggers an update.
    func seekTo(time: TimeInterval) {
        playbackManager.seekTo(time: time)
        DispatchQueue.main.async {
            self.currentTime = time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.updateMediaState()
            }
        }
    }
}
