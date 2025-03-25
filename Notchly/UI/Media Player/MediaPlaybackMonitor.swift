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
    /// Listens for system notifications and uses several polling timers (fallback, constant, end-of-track, and duration polling)
    /// to keep the UI in sync even when the system data is delayed or imperfect.
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
        
        /// Temporarily holds the expected play state (after user actions) along with its timestamp.
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
        /// Queries for the latest now-playing info, reconciles with expected state, and updates published properties.
        func updateMediaState() {
            if isToggledManually {
                // Skip updates if a user toggle is in progress.
                return
            }
            
            playbackManager.getNowPlayingInfo { [weak self] info in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    // Valid info received.
                    if let info = info, !info.title.isEmpty {
                        // Log track changes (if any).
                        if self.nowPlaying?.title != info.title {
                            print("🎵 Track change: '\(self.nowPlaying?.title ?? "none")' → '\(info.title)'")
                        }
                        
                        // Validate duration.
                        var validDuration: TimeInterval = info.duration
                        if info.duration <= 1.0 {
                            if let current = self.nowPlaying, current.title == info.title, self.lastValidDuration > 1.0 {
                                validDuration = self.lastValidDuration
                                print("🔄 Bogus Media Duration received; reusing cached duration: \(validDuration)s")
                            } else {
                                print("⏱ Bogus Media Duration (\(info.duration)s) – retrying shortly...")
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
                        
                        // Enforce expected state if one exists.
                        if let expected = self.expectedPlayState, let ts = self.expectedStateTimestamp {
                            let elapsed = Date().timeIntervalSince(ts)
                            if elapsed < 1.5 {
                                print("⌚ Enforcing expected state (\(expected)) for \(String(format: "%.1fs", elapsed))")
                                self.isPlaying = expected
                            } else {
                                self.expectedPlayState = nil
                                self.expectedStateTimestamp = nil
                                self.isPlaying = info.isPlaying
                                print("⌚ Expected state stale – trusting system state (\(info.isPlaying))")
                            }
                        } else {
                            self.isPlaying = info.isPlaying
                        }
                        
                        self.nowPlaying = info
                        let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                        if !self.isScrubbing {
                            self.currentTime = clampedElapsed
                        }
                        
                        // Start or stop the progress timer based on state.
                        if self.isPlaying {
                            self.cancelFallbackPolling()
                            self.startProgressTimer()
                        } else {
                            self.stopProgressTimer()
                        }
                    } else {
                        // No valid info received; retain last state if recent.
                        if let lastUpdate = self.lastValidUpdate,
                           Date().timeIntervalSince(lastUpdate) < 3.0 {
                            // Do nothing—retain state.
                        } else {
                            self.clearMediaState()
                        }
                        self.endPollingTimer?.invalidate()
                        self.endPollingTimer = nil
                        return
                    }
                    
                    // --- End-of-Track Polling ---
                    let remainingTime = self.duration - self.currentTime
                    let threshold = max(3.0, 0.05 * self.duration)
                    if self.isPlaying && remainingTime < threshold {
                        if self.endPollingTimer == nil {
                            print("⏱ Near track end (\(String(format: "%.1fs", remainingTime)) remaining); polling frequently.")
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
        /// Polls every 1 second if no valid info is received.
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
        /// Constantly polls for updates every 1 second while media is playing.
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
        /// High-frequency polling (every 0.25s) when bogus duration data is encountered.
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
        /// Clears the current media state and starts fallback polling.
        private func clearMediaState() {
            self.nowPlaying = nil
            self.isPlaying = false
            self.currentTime = 0
            self.lastValidUpdate = nil
            self.startFallbackPolling()
        }
        
        // MARK: - Progress Timer
        /// Starts a timer to update currentTime every 0.1 seconds.
        func startProgressTimer() {
            progressTimer?.invalidate()
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.fetchElapsedTime()
            }
        }
        
        func stopProgressTimer() {
            progressTimer?.invalidate()
        }
        
        /// Fetches elapsed time from the system and updates currentTime, clamped between 0 and duration.
        func fetchElapsedTime() {
            if self.isScrubbing { return }  // Skip updates during scrubbing.
            playbackManager.getNowPlayingInfo { [weak self] info in
                guard let self = self, let info = info, self.isPlaying else { return }
                DispatchQueue.main.async {
                    let clampedElapsed = max(0, min(info.elapsedTime, self.duration))
                    self.currentTime = clampedElapsed
                }
            }
        }
        
        // MARK: - Playback Actions
        /// Sends a previous track command and forces multiple updates.
        func previousTrack() {
            playbackManager.previousTrack()
            DispatchQueue.main.async { self.updateMediaState() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateMediaState() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.updateMediaState() }
        }
        
        /// Sends a next track command and forces multiple updates.
        func nextTrack() {
            playbackManager.nextTrack()
            DispatchQueue.main.async { self.updateMediaState() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateMediaState() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.updateMediaState() }
        }
        
        /// Toggles play/pause, sets an expected state, and schedules updates.
        func togglePlayPause() {
            let newState = !self.isPlaying
            self.expectedPlayState = newState
            self.expectedStateTimestamp = Date()
            
            self.isToggledManually = true
            self.isPlaying = newState
            playbackManager.togglePlayPause(isPlaying: newState)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.updateMediaState()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                self.isToggledManually = false
                self.updateMediaState()
            }
        }
        
        /// Seeks to a given time in the track and then updates state.
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
