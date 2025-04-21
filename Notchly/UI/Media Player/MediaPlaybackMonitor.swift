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
    
    // MARK: - Published Properties
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = "Unknown"
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var isScrubbing: Bool = false
    
    // MARK: - Internal State
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
    private var pollingTimerCancellable: AnyCancellable?
    private var progressTimer: Timer?  // (unused)
    
    private let mediaPlayerAppProvider: MediaPlayerAppProvider

    // MARK: - Init
    init() {
        self.mediaPlayerAppProvider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject<AlertItem, Never>())
        setupObservers()
        updatePollingInterval()
        startPolling()
    }

    // MARK: - Lifecycle Management
    func suspendUpdates() {
        print("⏸ MediaPolling: Suspended")
        pausePolling()
    }

    func resumeUpdates() {
        print("▶️ MediaPolling: Resumed")
        resumePolling()
        updateMediaState()
    }

    deinit {
        print("🧹 MediaPlaybackMonitor deinit")
        pollingTimerCancellable?.cancel()
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Observers
    private func setupObservers() {
        [
            NSNotification.Name("com.apple.Music.playerInfo"),
            NSNotification.Name("com.spotify.client.PlaybackStateChanged")
        ].forEach {
            NotificationCenter.default.publisher(for: $0)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.updateMediaState() }
                .store(in: &cancellables)
        }

        NotificationCenter.default.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                               object: nil,
                                               queue: .main) { [weak self] notification in
            if let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               terminatedApp.bundleIdentifier == "com.apple.Music" {
                print("🛑 Music app terminated; clearing media state.")
                Task { @MainActor in self?.clearMediaState() }
            }
        }
    }

    // MARK: - Polling Control
    func pausePolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = nil
    }

    func resumePolling() {
        updatePollingInterval()
        startPolling()
    }

    private func updatePollingInterval() {
        let desired = isPlaying ? 0.2 : 1.0
        if desired != pollingInterval {
            pollingInterval = desired
            startPolling()
        }
    }

    private func startPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = Timer.publish(every: pollingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateMediaState() }
    }

    private func stopPolling() {
        pollingTimerCancellable?.cancel()
        pollingTimerCancellable = nil
    }

    // MARK: - State Update
    func updateMediaState() {
        guard let activePlayer = mediaPlayerAppProvider.getActivePlayer() else {
            clearMediaState()
            return
        }

        activePlayerName = activePlayer.appName
        if isToggledManually { return }

        activePlayer.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let info = info, !info.title.isEmpty else {
                    if let last = self.lastValidUpdate,
                       Date().timeIntervalSince(last) >= 3 {
                        print("🛑 No valid media info for too long; clearing")
                        self.clearMediaState()
                    }
                    return
                }

                if self.nowPlaying?.title != info.title || self.nowPlaying?.artist != info.artist {
                    print("🎵 Now playing: \(info.title) — \(info.artist)")
                }

                var validDuration = info.duration
                if validDuration <= 1.0 {
                    if let current = self.nowPlaying,
                       current.title == info.title,
                       self.lastValidDuration > 1.0 {
                        validDuration = self.lastValidDuration
                        print("🔄 Using cached duration: \(validDuration)s")
                    } else {
                        print("⚠️ Missing or invalid duration for '\(info.title)', retrying...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.updateMediaState()
                        }
                        return
                    }
                } else {
                    self.lastValidDuration = validDuration
                }

                self.lastValidUpdate = Date()
                let newState = info.isPlaying

                if let expected = self.expectedPlayState,
                   let ts = self.expectedStateTimestamp,
                   Date().timeIntervalSince(ts) < 1.5 {
                    if self.isPlaying != expected {
                        print("⌚ Enforcing expected state: \(expected)")
                        self.isPlaying = expected
                    }
                } else {
                    self.expectedPlayState = nil
                    self.expectedStateTimestamp = nil
                    if self.isPlaying != newState {
                        print("⏯️ Playback status changed → \(newState ? "▶️ Playing" : "⏸️ Paused")")
                        self.isPlaying = newState
                    }
                }

                if !self.isScrubbing {
                    self.baseElapsed = max(0, min(info.elapsedTime, validDuration))
                    self.lastUpdateTimestamp = Date()
                }

                let updatedInfo = NowPlayingInfo(
                    title: info.title,
                    artist: info.artist,
                    album: info.album,
                    duration: validDuration,
                    elapsedTime: self.isScrubbing ? self.currentTime : self.baseElapsed,
                    isPlaying: newState,
                    artwork: info.artwork,
                    appName: info.appName
                )

                self.nowPlaying = updatedInfo
                self.duration = updatedInfo.duration
                self.currentTime = updatedInfo.elapsedTime
                self.updatePollingInterval()
            }
        }
    }

    // MARK: - Controls
    func previousTrack() {
        mediaPlayerAppProvider.getActivePlayer()?.previousTrack()
        DispatchQueue.main.async { self.updateMediaState() }
    }

    func nextTrack() {
        mediaPlayerAppProvider.getActivePlayer()?.nextTrack()
        DispatchQueue.main.async { self.updateMediaState() }
    }

    func togglePlayPause() {
        guard let player = mediaPlayerAppProvider.getActivePlayer() else { return }
        let newState = !isPlaying
        expectedPlayState = newState
        expectedStateTimestamp = Date()
        isToggledManually = true
        isPlaying = newState
        player.playPause()
        DispatchQueue.main.async {
            self.updateMediaState()
            self.isToggledManually = false
        }
    }

    func seekTo(time: TimeInterval) {
        mediaPlayerAppProvider.getActivePlayer()?.seekTo(time: time)
        DispatchQueue.main.async {
            self.currentTime = time
            self.updateMediaState()
        }
    }

    // MARK: - Cleanup
    private func clearMediaState() {
        isPlaying = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.nowPlaying = nil
            self.currentTime = 0
            self.lastValidUpdate = nil
            self.activePlayerName = ""
        }
    }
}
