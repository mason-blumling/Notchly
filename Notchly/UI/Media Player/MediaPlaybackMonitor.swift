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
    
    // MARK: - Singleton
    static let shared = MediaPlaybackMonitor()
    
    // MARK: - Published Properties (UI Observables)
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = "Unknown"
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private State Variables
    private var cancellables = Set<AnyCancellable>()
    private var lastValidUpdate: Date? = nil
    private var lastValidDuration: TimeInterval = 0
    private var isToggledManually = false
    private var expectedPlayState: Bool? = nil
    private var expectedStateTimestamp: Date? = nil
    
    // Baseline values for interpolation when polling (if needed)
    private var baseElapsed: TimeInterval = 0
    private var lastUpdateTimestamp: Date = Date()
    
    // Adaptive polling: current polling interval (in seconds)
    private var pollingInterval: TimeInterval = 1.0
    
    // MARK: - Provider
    /// Uses MediaPlayerAppProvider to determine which media app (Apple Music, Spotify, Podcasts) is active.
    private let mediaPlayerAppProvider: MediaPlayerAppProvider
    
    // Polling timer using Combine.
    private var pollingTimerCancellable: AnyCancellable?
    
    // (Optional) High-frequency timer for interpolation – not used in this version.
    private var progressTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        // Initialize the provider with a notification subject.
        self.mediaPlayerAppProvider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject<AlertItem, Never>())
        setupObservers()
        updatePollingInterval() // Set initial polling interval
        startPolling()
    }
    
    // MARK: - Observers Setup
    /// Sets up Combine subscriptions to system notifications from media apps.
    private func setupObservers() {
        // Listen for notifications from Apple Music and Spotify.
        let notifications = [
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
        
        // Listen for termination notifications for the Music app to clear state.
        NotificationCenter.default.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                               object: nil,
                                               queue: .main) { [weak self] notification in
            if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               terminatedApp.bundleIdentifier == "com.apple.Music" {
                print("🛑 Music app terminated; clearing media state.")
                Task { @MainActor in
                    self?.clearMediaState()
                }
            }
        }
    }
    
    // MARK: - Adaptive Polling
    /// Adjusts the polling interval based on whether media is playing.
    private func updatePollingInterval() {
        // When playing, poll faster (0.2 seconds); when paused (or idle), poll slower (1.0 second).
        let desiredInterval: TimeInterval = self.isPlaying ? 0.2 : 1.0
        if desiredInterval != pollingInterval {
            pollingInterval = desiredInterval
            startPolling()  // Restart polling with the new interval.
        }
    }
    
    /// Starts the Combine-based polling timer with the current pollingInterval.
    private func startPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = Timer.publish(every: pollingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMediaState()
            }
    }
    
    /// Stops the polling timer.
    private func stopPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = nil
    }
    
    // MARK: - Main Update Logic
    /// Fetches now-playing information from the active media player and updates UI state.
    func updateMediaState() {
        // Query the provider for the active player.
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else {
            clearMediaState()
            return
        }
        
        // Update the activePlayerName property.
        activePlayerName = activePlayer.appName
        
        // If playback state was manually toggled, skip auto-update.
        if isToggledManually { return }
        
        activePlayer.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // If no valid info is returned and it's been too long, clear state.
                guard let info = info, !info.title.isEmpty else {
                    if let lastUpdate = self.lastValidUpdate,
                       Date().timeIntervalSince(lastUpdate) >= 3.0 {
                        print("🛑 No valid media info for too long; returning to idle view.")
                        self.clearMediaState()
                    }
                    return
                }
                
                // Log track change if title differs.
                if self.nowPlaying?.title != info.title {
                    print("🎵 Track change: '\(self.nowPlaying?.title ?? "none")' → '\(info.title)'")
                }
                
                // Validate and cache duration.
                var validDuration = info.duration
                if info.duration <= 1.0 {
                    if let current = self.nowPlaying, current.title == info.title, self.lastValidDuration > 1.0 {
                        validDuration = self.lastValidDuration
                        print("🔄 Bogus duration; using cached duration: \(validDuration)s")
                    } else {
                        print("⏱ Bogus duration (\(info.duration)s) – retrying shortly...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.updateMediaState()
                        }
                        return
                    }
                } else {
                    validDuration = info.duration
                    self.lastValidDuration = validDuration
                }
                
                let updatedDuration = max(validDuration, 1)
                self.lastValidUpdate = Date()
                
                // Update isPlaying state using expected state logic.
                if let expected = self.expectedPlayState,
                   let ts = self.expectedStateTimestamp,
                   Date().timeIntervalSince(ts) < 1.5 {
                    if self.isPlaying != expected {
                        print("⌚ Enforcing expected state (\(expected))")
                        self.isPlaying = expected
                    }
                } else {
                    self.expectedPlayState = nil
                    self.expectedStateTimestamp = nil
                    if self.isPlaying != info.isPlaying {
                        print("⌚ Updating isPlaying to fetched value (\(info.isPlaying))")
                        self.isPlaying = info.isPlaying
                    }
                }
                
                // When not scrubbing, update baseline and currentTime.
                let newElapsed: TimeInterval
                if !self.isScrubbing {
                    newElapsed = max(0, min(info.elapsedTime, updatedDuration))
                    self.baseElapsed = newElapsed
                    self.lastUpdateTimestamp = Date()
                } else {
                    newElapsed = self.currentTime
                    print("updateMediaState: User is scrubbing, preserving currentTime")
                }
                
                // Update the nowPlaying model.
                let updatedInfo = NowPlayingInfo(
                    title: info.title,
                    artist: info.artist,
                    album: info.album,
                    duration: updatedDuration,
                    elapsedTime: newElapsed,
                    isPlaying: info.isPlaying,
                    artwork: info.artwork,
                    appName: info.appName
                )
                
                self.nowPlaying = updatedInfo
                self.duration = updatedInfo.duration
                self.currentTime = updatedInfo.elapsedTime
                
                // Adjust polling interval based on the new state.
                self.updatePollingInterval()
            }
        }
    }
    
    // MARK: - Playback Actions
    func previousTrack() {
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else { return }
        activePlayer.previousTrack()
        DispatchQueue.main.async {
            self.updateMediaState()
        }
    }
    
    func nextTrack() {
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else { return }
        activePlayer.nextTrack()
        DispatchQueue.main.async {
            self.updateMediaState()
        }
    }
    
    func togglePlayPause() {
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else { return }
        let newState = !self.isPlaying
        self.expectedPlayState = newState
        self.expectedStateTimestamp = Date()
        
        self.isToggledManually = true
        self.isPlaying = newState
        activePlayer.playPause()
        
        DispatchQueue.main.async {
            self.updateMediaState()
            self.isToggledManually = false
        }
    }
    
    func seekTo(time: TimeInterval) {
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else { return }
        activePlayer.seekTo(time: time)
        DispatchQueue.main.async {
            self.currentTime = time
            self.updateMediaState()
        }
    }
    
    // MARK: - Clearing State
    /// Clears all media-related state to return the UI to the idle view.
    private func clearMediaState() {
        // Step 1: Set isPlaying = false first to trigger transition
        self.isPlaying = false

        // Step 2: Allow the animation to play before killing the model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nowPlaying = nil
            self.currentTime = 0
            self.lastValidUpdate = nil
            self.activePlayerName = ""
        }
    }
}
