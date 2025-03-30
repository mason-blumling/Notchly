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
    @Published private(set) var activePlayer: String = "Unknown"
    
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
    
    // MARK: - Media Provider
    private let mediaProvider: PlayerProtocol = AppleMusicManager(notificationSubject: PassthroughSubject<AlertItem, Never>())
    private var pollingTimerCancellable: AnyCancellable?
    private var progressTimer: Timer?

    // MARK: - Initialization
    private init() {
        setupObservers()
        startPolling()
    }
    
    // MARK: - Observers Setup
    private func setupObservers() {
        // In this new design, we only need notifications from Apple Music (and Spotify if needed).
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
        
        NotificationCenter.default.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               terminatedApp.bundleIdentifier == "com.apple.Music" {
                print("🛑 Music app terminated; clearing media state.")
                Task { @MainActor in
                    self?.clearMediaState()
                }
            }
        }
    }
    
    // MARK: - Main Update Logic
    func updateMediaState() {
        // Check if the media provider's app is running
        if !mediaProvider.isAppRunning() {
            print("🛑 Media app not running; clearing media state.")
            self.clearMediaState()
            return
        }
        
        if isToggledManually { return }
        
        mediaProvider.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let info = info, !info.title.isEmpty {
                    if self.nowPlaying?.title != info.title {
                        print("🎵 Track change: '\(self.nowPlaying?.title ?? "none")' → '\(info.title)'")
                    }
                    
                    // Validate duration
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
                    self.activePlayer = info.appName
                    self.lastValidUpdate = Date()
                    
                    // Update isPlaying state using expected state logic
                    if let expected = self.expectedPlayState, let ts = self.expectedStateTimestamp, Date().timeIntervalSince(ts) < 1.5 {
                        // Only update if the current state isn't already what we expect.
                        if self.isPlaying != expected {
                            print("⌚ Enforcing expected state (\(expected)) for \(String(format: "%.1fs", Date().timeIntervalSince(ts)))")
                            self.isPlaying = expected
                        }
                    } else {
                        // Clear expected state and update only if the fetched state differs.
                        self.expectedPlayState = nil
                        self.expectedStateTimestamp = nil
                        if self.isPlaying != info.isPlaying {
                             print("⌚ Updating isPlaying to fetched value (\(info.isPlaying))")
                             self.isPlaying = info.isPlaying
                        }
                    }
                    
                    self.nowPlaying = info
                    
                    // Only update currentTime if user is not scrubbing
                    if !self.isScrubbing {
                        let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                        self.currentTime = clampedElapsed
                    } else {
                        print("updateMediaState: User is scrubbing, preserving currentTime")
                    }
                    
                    // Start or stop the smooth progress timer
                    if self.isPlaying {
                        self.startProgressTimer()
                    } else {
                        self.stopProgressTimer()
                    }
                } else {
                    // No valid info received.
                    if let lastUpdate = self.lastValidUpdate, Date().timeIntervalSince(lastUpdate) < 3.0 {
                        // Retain state if recent.
                    } else {
                        print("🛑 No valid media info for too long; returning to idle view.")
                        self.clearMediaState()
                    }
                    return
                }
            }
        }
    }
    
    // MARK: - Progress Timer
    func fetchElapsedTime() {
        if self.isScrubbing { return }
        mediaProvider.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info, self.isPlaying else { return }
            DispatchQueue.main.async {
                let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                self.currentTime = clampedElapsed
            }
        }
    }
    
    // MARK: - Playback Actions
    func previousTrack() {
        mediaProvider.previousTrack()
        DispatchQueue.main.async {
            self.updateMediaState()
        }
    }
    
    func nextTrack() {
        mediaProvider.nextTrack()
        DispatchQueue.main.async {
            self.updateMediaState()
        }
    }
    
    func togglePlayPause() {
        let newState = !self.isPlaying
        self.expectedPlayState = newState
        self.expectedStateTimestamp = Date()
        
        self.isToggledManually = true
        self.isPlaying = newState
        mediaProvider.playPause()
        
        // Remove legacy delays: call updateMediaState immediately.
        DispatchQueue.main.async {
            self.updateMediaState()
            self.isToggledManually = false
        }
    }
    
    func seekTo(time: TimeInterval) {
        mediaProvider.seekTo(time: time)
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
    
    private func startPolling() {
        pollingTimerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMediaState()
            }
    }

    private func stopPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = nil
    }
    
    // MARK: - High-Frequency Progress Timer for Smooth Scrubber Updates
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isPlaying, !self.isScrubbing else { return }
                self.currentTime += 0.1
                if self.currentTime >= self.duration {
                    self.currentTime = self.duration
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
