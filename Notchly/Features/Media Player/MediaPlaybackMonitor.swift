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
/// and only polls when expanded (relying on DistributedNotifications when collapsed).
@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    
    // MARK: - Published Properties

    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = ""
    
    /// All time properties derived from a single source
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var progress: CGFloat = 0
    @Published var elapsedTime: String = "0:00"
    @Published var remainingTime: String = "-0:00"
    
    /// Scrubbing state
    @Published var isScrubbing: Bool = false
    
    /// Format time consistently - no animation placeholders
    var formattedElapsedTime: String {
        let totalSeconds = Int(currentTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedRemainingTime: String {
        let totalSeconds = Int(duration - currentTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "-%d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Properties

    private var provider: MediaPlayerAppProvider
    private var updateTimer: Timer?
    private var fetchTimer: Timer?
    private var lastFetchTime: TimeInterval = 0
    private var lastFetchDate: Date = Date()
    private var lastValidDuration: TimeInterval = 0
    
    // MARK: - Initialization

    init() {
        provider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject())
        setupNotifications()
    }
    
    deinit {
        updateTimer?.invalidate()
        fetchTimer?.invalidate()
    }
    
    // MARK: - Timer Controls

    func startTimer() {
        /// Cancel existing timers
        updateTimer?.invalidate()
        fetchTimer?.invalidate()
        updateTimer = nil
        fetchTimer = nil
        
        /// Start update timer for UI updates (runs frequently)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackState()
            }
        }
        
        /// Start fetch timer for getting fresh data (runs less frequently)
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.fetchMediaState()
            }
        }
        
        /// Fetch immediately
        fetchMediaState()
    }
    
    func stopTimer() {
        updateTimer?.invalidate()
        fetchTimer?.invalidate()
        updateTimer = nil
        fetchTimer = nil
    }
    
    // MARK: - Playback State Updates

    private func updatePlaybackState() {
        guard !isScrubbing else { return }
        
        /// Update current time if playing
        if isPlaying {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastFetchDate)
            currentTime = min(lastFetchTime + elapsed, duration)
            progress = duration > 0 ? currentTime / duration : 0
            
            /// Update formatted times
            elapsedTime = formattedElapsedTime
            remainingTime = formattedRemainingTime
        }
    }
    
    // MARK: - Expansion Control

    func setExpanded(_ expanded: Bool) {
        if expanded {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    // MARK: - Media Controls

    func togglePlayPause() {
        guard let player = provider.getActivePlayer() else { return }
        
        /// Optimistically update state
        isPlaying.toggle()
        player.playPause()
        
        /// Fetch fresh state after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.fetchMediaState()
        }
    }
    
    func previousTrack() {
        provider.getActivePlayer()?.previousTrack()
        
        /// Brief delay before fetching new track info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fetchMediaState()
        }
    }
    
    func nextTrack() {
        provider.getActivePlayer()?.nextTrack()
        
        /// Brief delay before fetching new track info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fetchMediaState()
        }
    }
    
    func seekTo(time: TimeInterval) {
        guard let player = provider.getActivePlayer() else { return }
        
        /// Update local state immediately
        currentTime = time
        progress = duration > 0 ? time / duration : 0
        elapsedTime = formattedElapsedTime
        remainingTime = formattedRemainingTime
        
        /// Send command to player
        player.seekTo(time: time)
        
        /// Update last fetch time
        lastFetchTime = time
        lastFetchDate = Date()
    }
    
    // MARK: - State Fetching

    private func fetchMediaState() {
        guard let player = provider.getActivePlayer(), player.isAppRunning() else {
            clearState()
            return
        }
        
        activePlayerName = player.appName
        
        player.getNowPlayingInfo { [weak self] info in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let info = info else {
                    self.clearState()
                    return
                }
                
                // Force update by creating a new instance
                // This ensures SwiftUI detects the change
                self.nowPlaying = NowPlayingInfo(
                    title: info.title,
                    artist: info.artist,
                    album: info.album,
                    duration: info.duration,
                    elapsedTime: info.elapsedTime,
                    isPlaying: info.isPlaying,
                    artwork: info.artwork,
                    appName: info.appName
                )
                
                self.isPlaying = info.isPlaying
                
                /// Update duration
                if info.duration > 1 {
                    self.duration = info.duration
                    self.lastValidDuration = info.duration
                } else if self.lastValidDuration > 1 {
                    self.duration = self.lastValidDuration
                }
                
                /// Smooth time synchronization to prevent jumps
                if !self.isScrubbing {
                    let serverTime = info.elapsedTime
                    let currentInterpolatedTime = self.currentTime
                    let timeDifference = abs(serverTime - currentInterpolatedTime)
                    
                    /// Only hard-sync if the difference is significant (> 1 second)
                    if timeDifference > 1.0 {
                        /// Hard sync for large differences
                        self.currentTime = serverTime
                        self.lastFetchTime = serverTime
                        self.lastFetchDate = Date()
                    } else {
                        /// Gradually adjust for small differences
                        let adjustment = (serverTime - currentInterpolatedTime) * 0.2
                        self.currentTime += adjustment
                        self.lastFetchTime = self.currentTime
                        self.lastFetchDate = Date()
                    }
                    
                    self.progress = self.duration > 0 ? self.currentTime / self.duration : 0
                    self.elapsedTime = self.formattedElapsedTime
                    self.remainingTime = self.formattedRemainingTime
                } else {
                    /// When scrubbing, just update reference times
                    self.lastFetchTime = info.elapsedTime
                    self.lastFetchDate = Date()
                }
            }
        }
    }

    private func clearState() {
        nowPlaying = nil
        isPlaying = false
        activePlayerName = ""
        currentTime = 0
        duration = 1
        progress = 0
        elapsedTime = "0:00"
        remainingTime = "-0:00"
        lastValidDuration = 0
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        let distCenter = DistributedNotificationCenter.default()

        distCenter.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetchMediaState()
            }
        }

        distCenter.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetchMediaState()
            }
        }
    }
}
