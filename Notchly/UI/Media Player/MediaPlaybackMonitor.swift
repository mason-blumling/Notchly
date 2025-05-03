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
/// and **only** polls when expanded (relying on DistributedNotifications when collapsed).
@MainActor
final class MediaPlaybackMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var nowPlaying: NowPlayingInfo?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var activePlayerName: String = ""
    
    // All time properties derived from a single source
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var progress: CGFloat = 0
    @Published var displayTimes: (elapsed: String, remaining: String) = ("0:00", "-0:00")
    
    @Published var isScrubbing: Bool = false
    
    // MARK: - Private Properties
    private var lastValidDuration: TimeInterval = 0
    private var lastFetchTime: TimeInterval = 0
    private var lastFetchDate: Date = Date()
    private var isInterpolating: Bool = false
    
    private var provider: MediaPlayerAppProvider
    private var updateTimer: Timer?
    private var fetchTimer: Timer?
    
    // MARK: - Initialization
    init() {
        provider = MediaPlayerAppProvider(notificationSubject: PassthroughSubject())
        setupNotifications()
    }
    
    deinit {
        updateTimer?.invalidate()
        fetchTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func setExpanded(_ expanded: Bool) {
        // Clear existing timers
        updateTimer?.invalidate()
        fetchTimer?.invalidate()
        updateTimer = nil
        fetchTimer = nil
        
        guard expanded else {
            isInterpolating = false
            return
        }
        
        // When expanded, start updating
        isInterpolating = true
        
        // Fetch actual state every 2 seconds
        fetchTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMediaState()
        }
        
        // Update display every 16ms (60fps)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateDisplayTime()
        }
        
        // Fetch immediately
        fetchMediaState()
    }
    
    // MARK: - Controls
    func togglePlayPause() {
        guard let player = provider.getActivePlayer() else { return }
        
        // Toggle state immediately for responsiveness
        isPlaying = !isPlaying
        player.playPause()
        
        // Fetch actual state to sync
        fetchMediaState()
    }
    
    func previousTrack() {
        provider.getActivePlayer()?.previousTrack()
        fetchMediaState()
    }
    
    func nextTrack() {
        provider.getActivePlayer()?.nextTrack()
        fetchMediaState()
    }
    
    func seekTo(time: TimeInterval) {
        guard let player = provider.getActivePlayer() else { return }
        
        // Update immediately for responsiveness
        lastFetchTime = time
        lastFetchDate = Date()
        updateDisplayFromTime(time)
        
        player.seekTo(time: time)
        
        // Verify with server
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchMediaState()
        }
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        let distCenter = DistributedNotificationCenter.default()
        
        // Listen for media player notifications
        distCenter.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] _ in
            self?.fetchMediaState()
        }
        
        distCenter.addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.fetchMediaState()
        }
    }
    
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
                
                // Update state
                self.nowPlaying = info
                self.isPlaying = info.isPlaying
                self.activePlayerName = self.provider.getActivePlayer()?.appName ?? ""
                
                // Update or validate duration
                if info.duration > 1 {
                    self.lastValidDuration = info.duration
                    self.duration = info.duration
                } else if self.lastValidDuration > 1 {
                    self.duration = self.lastValidDuration
                }
                
                // Store fetch time for interpolation
                self.lastFetchTime = info.elapsedTime
                self.lastFetchDate = Date()
                
                // Update display immediately unless scrubbing
                if !self.isScrubbing {
                    self.updateDisplayFromTime(info.elapsedTime)
                }
            }
        }
    }
    
    private func updateDisplayTime() {
        guard isInterpolating && isPlaying && !isScrubbing else { return }
        
        // Calculate interpolated time
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetchDate)
        let interpolatedTime = lastFetchTime + timeSinceLastFetch
        
        // Update display
        updateDisplayFromTime(interpolatedTime)
    }
    
    private func updateDisplayFromTime(_ time: TimeInterval) {
        // Ensure time is within bounds
        let boundedTime = max(0, min(time, duration))
        
        // Calculate all values
        let elapsed = boundedTime
        let remaining = duration - boundedTime
        let progress = duration > 0 ? boundedTime / duration : 0
        
        // Format times
        let elapsedString = formatTime(elapsed)
        let remainingString = "-\(formatTime(remaining))"
        
        // Update all published properties at once
        currentTime = boundedTime
        self.progress = CGFloat(progress)
        displayTimes = (elapsed: elapsedString, remaining: remainingString)
    }
    
    private func clearState() {
        nowPlaying = nil
        isPlaying = false
        activePlayerName = ""
        currentTime = 0
        duration = 1
        progress = 0
        displayTimes = ("0:00", "-0:00")
        lastValidDuration = 0
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, timeInterval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
