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

@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    static let shared = MediaPlaybackMonitor()
    
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayer: String = "Unknown"
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var fallbackTimer: Timer?
    private var expectedStateTimestamp: Date? = nil
    
    // Force-initialize the playback manager.
    private let playbackManager: MediaPlaybackManager = {
        guard let manager = MediaPlaybackManager() else {
            fatalError("Failed to initialize MediaPlaybackManager")
        }
        return manager
    }()
    
    // Flags & state trackers.
    private var isToggledManually = false
    private var lastValidUpdate: Date? = nil
    private var lastValidDuration: TimeInterval = 0
    
    /// This property stores the play state that we expect after a user action.
    private var expectedPlayState: Bool? = nil
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Observers: Listen to system media notifications.
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
    
    // MARK: - Main Update Logic: Reconciling Expected State with System Info.
    func updateMediaState() {
        if isToggledManually {
            print("updateMediaState: Skipped due to manual toggle")
            return
        }
        
        playbackManager.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let info = info, !info.title.isEmpty else {
                    if let lastUpdate = self.lastValidUpdate, Date().timeIntervalSince(lastUpdate) < 3.0 {
                        let elapsed = Date().timeIntervalSince(lastUpdate)
                        print("updateMediaState: Empty info, retaining last valid state (last update \(elapsed)s ago)")
                    } else {
                        print("updateMediaState: Empty info for too long. Clearing state and starting fallback polling.")
                        self.clearMediaState()
                    }
                    return
                }
                
                // Check for bogus duration.
                if info.duration <= 1.0 {
                    // Start high-frequency polling if not already started.
                    if self.durationPollingTimer == nil {
                        print("updateMediaState: Bogus duration (\(info.duration)). Starting duration polling.")
                        self.startDurationPolling()
                    }
                    // Don't update UI with bogus data.
                    return
                } else {
                    // If valid duration, cancel the high-frequency polling.
                    self.cancelDurationPolling()
                }
                
                print("updateMediaState: Received valid info -> \(info)")
                
                let durationToUse: TimeInterval = info.duration  // now it's valid
                self.lastValidDuration = durationToUse
                self.duration = max(durationToUse, 1)
                self.activePlayer = info.appName
                self.lastValidUpdate = Date()
                
                // Reconcile expected state if set.
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
                let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                self.currentTime = clampedElapsed
                
                if self.isPlaying {
                    self.cancelFallbackPolling()
                    self.startProgressTimer()
                    print("updateMediaState: Media is playing (enforced state: \(self.isPlaying))")
                } else {
                    self.stopProgressTimer()
                    print("updateMediaState: Media is paused (enforced state: \(self.isPlaying))")
                }
            }
        }
    }

    // MARK: - Fallback Polling: Poll every second when state is cleared.
    private func startFallbackPolling() {
        if fallbackTimer != nil { return }
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                print("Fallback polling triggered updateMediaState")
                self?.updateMediaState()
            }
        }
    }
    
    // Add this property to your MediaPlaybackMonitor class (near the others):
    private var durationPollingTimer: Timer? = nil

    // New helper functions:
    private func startDurationPolling() {
        if durationPollingTimer != nil { return }
        print("startDurationPolling: Starting high-frequency polling for valid duration")
        durationPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateMediaState()
        }
    }

    private func cancelDurationPolling() {
        durationPollingTimer?.invalidate()
        durationPollingTimer = nil
    }
    
    private func cancelFallbackPolling() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    // MARK: - Clear State: Clear nowPlaying and start fallback polling.
    private func clearMediaState() {
        print("clearMediaState: Clearing nowPlaying state")
        self.nowPlaying = nil
        self.isPlaying = false
        self.currentTime = 0
        self.lastValidUpdate = nil
        self.startFallbackPolling()
    }
    
    // MARK: - Progress Timer: Update current time every 0.1s.
    func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.fetchElapsedTime()
        }
    }
    
    func stopProgressTimer() {
        progressTimer?.invalidate()
    }
    
    /// Updates `currentTime` from the system.
    func fetchElapsedTime() {
        playbackManager.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info, self.isPlaying else { return }
            DispatchQueue.main.async {
                let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                self.currentTime = clampedElapsed
            }
        }
    }
    
    // MARK: - Playback Actions
    
    /// Delegates previous track command to the system.
    func previousTrack() {
        playbackManager.previousTrack()
        // Trigger multiple updates to catch the new track info quickly.
        DispatchQueue.main.async {
            self.updateMediaState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateMediaState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.updateMediaState()
        }
    }

    func nextTrack() {
        playbackManager.nextTrack()
        // Trigger multiple updates to catch the new track info quickly.
        DispatchQueue.main.async {
            self.updateMediaState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateMediaState()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.updateMediaState()
        }
    }
    
    /// Toggles play/pause and sets an expected state.

    func togglePlayPause() {
        let newState = !self.isPlaying
        // Store the expected state along with a timestamp.
        self.expectedPlayState = newState
        self.expectedStateTimestamp = Date()
        
        self.isToggledManually = true
        self.isPlaying = newState   // Immediately update UI for responsiveness.
        playbackManager.togglePlayPause(isPlaying: newState)
        print("togglePlayPause: Toggled to \(newState ? "Playing" : "Paused")")
        
        // Delay a re-check after 1.0s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateMediaState()
        }
        // Then clear the manual toggle flag after 1.35s and update state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            self.isToggledManually = false
            self.updateMediaState()
        }
    }
    
    /// Public method to seek within the track.
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
