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
    private let playbackManager = MediaPlaybackManager()

    private var lastFetchTimestamp: Date = .distantPast
    private var isToggledManually = false
    private var debounceToggle: DispatchWorkItem?

    private init() {
        setupObservers()
    }

    // MARK: - Setup Methods
    private func setupObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")))
            .merge(with: DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.Music.playerInfo")))
            .merge(with: DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.spotify.client.PlaybackStateChanged")))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchNowPlaying()
            }
            .store(in: &cancellables)
    }

    // MARK: - State Management
    func fetchNowPlaying() {
        print("🔍 fetchNowPlaying() CALLED at \(Date())") // Debugging log

        guard !isToggledManually else {
            print("🚨 fetchNowPlaying() SKIPPED - isToggledManually is TRUE")
            return
        }
        guard Date().timeIntervalSince(lastFetchTimestamp) > 0.8 else { // 🔹 Slightly longer debounce
            print("🚨 fetchNowPlaying() SKIPPED - Debounced")
            return
        }

        lastFetchTimestamp = Date()
        
        playbackManager?.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info else { return }

            DispatchQueue.main.async {
                self.updateState(from: info)
            }
        }
    }
    
    func fetchElapsedTime() {
        playbackManager?.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info else { return }
            
            DispatchQueue.main.async {
                self.currentTime = info.elapsedTime
            }
        }
    }
    
    func seekTo(time: TimeInterval) {
        playbackManager?.seekTo(time: time)

        DispatchQueue.main.async {
            self.currentTime = time
            self.fetchNowPlaying() // 🔹 Ensure metadata is accurate after seeking
        }
    }

    func previousTrack() {
        playbackManager?.previousTrack()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.fetchNowPlaying()
        }
    }
    
    func togglePlayPause(isPlaying: Bool) {
        let expectedState = !isPlaying
        isToggledManually = true

        print("🎵 Sending Play/Pause Command via MediaRemote")
        playbackManager?.togglePlayPause(isPlaying: expectedState)

        // LOCK UI STATE IMMEDIATELY (Prevents flicker)
        DispatchQueue.main.async {
            self.isPlaying = expectedState
        }

        // ⏳ DELAY FETCH TO PREVENT STALE STATE
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            self.fetchNowPlaying()
        }

        // 🔄 FINAL VALIDATION AFTER 1s (Catches delayed system updates)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            self.isToggledManually = false
            self.fetchNowPlaying()
        }
    }

    func nextTrack() {
        playbackManager?.nextTrack()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            self.fetchNowPlaying()
        }
    }

    private func updateState(from info: NowPlayingInfo) {
        let songChanged = (nowPlaying?.title != info.title || nowPlaying?.artist != info.artist || nowPlaying?.album != info.album)

        duration = max(info.duration, 1)
        activePlayer = info.appName

        if !isToggledManually && info.isPlaying != isPlaying {
            isPlaying = info.isPlaying
        }

        let timeDifference = abs(info.elapsedTime - currentTime)

        DispatchQueue.main.async {
            if songChanged {
                // ✅ Fully update everything when a new song starts
                self.nowPlaying = info
            } else {
                // ✅ If no song change, only update necessary fields (prevent artwork loss)
                self.nowPlaying = NowPlayingInfo(
                    title: info.title,
                    artist: info.artist,
                    album: info.album,
                    duration: info.duration,
                    elapsedTime: info.elapsedTime,
                    isPlaying: info.isPlaying,
                    artwork: info.artwork ?? self.nowPlaying?.artwork, // ✅ Preserve old artwork
                    appName: info.appName
                )
            }

            // ✅ Smooth transition for UI updates
            if timeDifference > 1.0 {
                self.currentTime = info.elapsedTime // Direct update for large gaps
            } else {
                withAnimation(.linear(duration: 0.3)) {
                    self.currentTime = info.elapsedTime // Smooth transition
                }
            }

            info.isPlaying ? self.startProgressTimer() : self.stopProgressTimer()
        }
    }

    // MARK: - Helper Methods
    private func detectActivePlayer() -> PlayerType? {
        _ = NSWorkspace.shared
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("🚨 No frontmost application detected!")
            return nil
        }

        print("🔎 Frontmost App Bundle ID: \(frontApp.bundleIdentifier ?? "Unknown")") // ✅ Log active app
        return .other
    }

    private func validateState() {
        guard (nowPlaying?.appName) != nil else { return }

        playbackManager?.getNowPlayingInfo { [weak self] info in
            guard let self = self, let info = info else { return }
            if info.isPlaying != self.isPlaying {
                self.isPlaying = info.isPlaying
            }
        }
    }

    // MARK: - Timer Methods
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.fetchElapsedTime()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
    }
}
