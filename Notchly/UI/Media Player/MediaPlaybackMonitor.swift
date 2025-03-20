//
//  MediaPlaybackMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import SwiftUI
import Combine
import AppKit

@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    static let shared = MediaPlaybackMonitor()

    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayer: String = "Unknown"

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1 // Avoid division by zero
    @Published var isScrubbing: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private let playbackManager = MediaPlaybackManager()

    private var lastFetchTimestamp: Date = .distantPast // Prevents race conditions
    private var isToggledManually = false // Track manual play/pause toggles
    private var debounceToggle: DispatchWorkItem? // Debounce for state sync

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")))
            .merge(with: DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.Music.playerInfo")))
            .merge(with: DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.spotify.client.PlaybackStateChanged")))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("Playback state changed")
                self?.fetchNowPlaying()
            }
            .store(in: &cancellables)
    }

    // 🔥 Timer for smooth scrubber updates
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, !self.isScrubbing else { return }
            self.fetchNowPlaying() // Fetch actual time instead of estimating
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
    }

    func fetchNowPlaying() {
        // Prevent excessive fetches within a short time (avoiding race conditions)
        guard Date().timeIntervalSince(lastFetchTimestamp) > 0.1 else { return }
        lastFetchTimestamp = Date()

        playbackManager?.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info else { return }
            DispatchQueue.main.async {
                let songChanged = (self.nowPlaying?.title != info.title || self.nowPlaying?.artist != info.artist)

                self.duration = max(info.duration, 1)
                self.activePlayer = info.appName

                // ✅ Only update `isPlaying` if it actually changed and not manually toggled
                if !self.isToggledManually && info.isPlaying != self.isPlaying {
                    self.isPlaying = info.isPlaying
                }

                // ✅ Ensure the scrubber remains accurate
                let timeDifference = abs(info.elapsedTime - self.currentTime)
                if songChanged || timeDifference > 1.0 {
                    self.nowPlaying = info
                    self.currentTime = info.elapsedTime
                }

                // ✅ Start or stop tracking based on play state
                info.isPlaying ? self.startProgressTimer() : self.stopProgressTimer()
            }
        }
    }

    // MARK: - 🎵 Play/Pause (Guaranteed Sync)
    func togglePlayPause() {
        // Cancel any pending sync operations
        debounceToggle?.cancel()

        // Immediate UI feedback
        isPlaying.toggle()
        isToggledManually = true

        // Send command to system
        playbackManager?.togglePlayPause(isPlaying: isPlaying)

        // Sync with actual state after short delay
        debounceToggle = DispatchWorkItem { [weak self] in
            self?.isToggledManually = false
            self?.fetchNowPlaying()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: debounceToggle!)
    }

    // MARK: - ⏩ Skip Tracks
    func nextTrack() {
        playbackManager?.nextTrack()
        fetchNowPlaying() // Fetch new state immediately
    }

    func previousTrack() {
        playbackManager?.previousTrack()
        fetchNowPlaying() // Fetch new state immediately
    }

    // MARK: - ⏳ Seeking (Accurate & Responsive)
    func seekTo(time: TimeInterval) {
        currentTime = time
        playbackManager?.seekTo(time: time)
        fetchNowPlaying()
    }
}

// MARK: - NowPlayingInfo
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var artwork: NSImage?
    var appName: String
}
