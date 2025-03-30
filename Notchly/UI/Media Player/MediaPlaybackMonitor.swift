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
@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    static let shared = MediaPlaybackMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = "Unknown"
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var lastValidUpdate: Date? = nil
    private var lastValidDuration: TimeInterval = 0
    private var isToggledManually = false
    private var expectedPlayState: Bool? = nil
    private var expectedStateTimestamp: Date? = nil
    
    // Baseline for interpolation (if needed)
    private var baseElapsed: TimeInterval = 0
    private var lastUpdateTimestamp: Date = Date()
    
    // Adaptive polling: current polling interval (in seconds)
    private var pollingInterval: TimeInterval = 1.0
    
    // Instead of a single mediaProvider, we now use a provider that decides the active player.
    private let mediaPlayerAppProvider: MediaPlayerAppProvider
    
    private var pollingTimerCancellable: AnyCancellable?
    // (Optional) High-frequency interpolation timer (if used).
    private var progressTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        // Initialize provider with a notification subject.
        self.mediaPlayerAppProvider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject<AlertItem, Never>())
        setupObservers()
        updatePollingInterval() // Set initial polling interval
        startPolling()
    }
    
    // MARK: - Observers Setup
    private func setupObservers() {
        // Listen for Music and Spotify notifications.
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
        
        // When the Music app terminates, clear state.
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
    private func updatePollingInterval() {
        // When playing, poll faster (0.2 s); when paused, poll slower (1.0 s).
        let desiredInterval: TimeInterval = self.isPlaying ? 0.2 : 1.0
        if desiredInterval != pollingInterval {
            pollingInterval = desiredInterval
            startPolling()  // Restart polling with the new interval.
        }
    }
    
    private func startPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = Timer.publish(every: pollingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMediaState()
            }
    }
    
    private func stopPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = nil
    }
    
    // MARK: - Main Update Logic
    func updateMediaState() {
        // Query the provider for the active player.
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else {
            print("No active player found; clearing media state.")
            clearMediaState()
            return
        }
        
        // Update the activePlayerName for UI display.
        activePlayerName = activePlayer.appName
        
        if isToggledManually { return }
        
        activePlayer.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let info = info, !info.title.isEmpty else {
                    if let lastUpdate = self.lastValidUpdate,
                       Date().timeIntervalSince(lastUpdate) >= 3.0 {
                        print("🛑 No valid media info for too long; returning to idle view.")
                        self.clearMediaState()
                    }
                    return
                }
                
                if self.nowPlaying?.title != info.title {
                    print("🎵 Track change: '\(self.nowPlaying?.title ?? "none")' → '\(info.title)'")
                }
                
                // Validate duration.
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
                
                self.duration = max(validDuration, 1)
                self.lastValidUpdate = Date()
                
                // Update isPlaying using expected state logic.
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
                
                self.nowPlaying = info
                
                // When not scrubbing, update currentTime directly from the source.
                if !self.isScrubbing {
                    let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                    self.currentTime = clampedElapsed
                } else {
                    print("updateMediaState: User is scrubbing, preserving currentTime")
                }
                
                // Adjust polling interval based on updated state.
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
    
    private func clearMediaState() {
        self.nowPlaying = nil
        self.isPlaying = false
        self.currentTime = 0
        self.lastValidUpdate = nil
    }
}
