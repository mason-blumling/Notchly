//
//  MediaPlaybackMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import SwiftUI
import Combine
import AppKit
import MediaPlayer

// MARK: - NowPlayingInfo
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var artwork: NSImage?
    var appURL: URL?
}

// MARK: - MediaPlaybackMonitor
class MediaPlaybackMonitor: ObservableObject {
    @Published var nowPlaying: NowPlayingInfo?
    @Published var isPlaying: Bool = false
    @Published var activePlayer: String = "Unknown"
    @Published var hasPermission: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var playbackManager = MediaPlaybackManager()
    private var pollingTimer: Timer?
    private var debounceWorkItem: DispatchWorkItem?

    private let mediaRemoteBundle: CFBundle
    private let MRMediaRemoteGetNowPlayingInfo: @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private let MRMediaRemoteRegisterForNowPlayingNotifications: @convention(c) (DispatchQueue) -> Void

    init?() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString),
              let MRMediaRemoteRegisterForNowPlayingNotificationsPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString)
        else { return nil }

        self.mediaRemoteBundle = bundle
        self.MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: (@convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void).self)
        self.MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(MRMediaRemoteRegisterForNowPlayingNotificationsPointer, to: (@convention(c) (DispatchQueue) -> Void).self)

        checkUserPermission()
        setupRemoteCommands()
        setupNowPlayingObserver()
        setThrottledPolling(enabled: true)
    }

    private func checkUserPermission() {
        if let permission = UserDefaults.standard.object(forKey: "MediaPlaybackPermission") as? Bool {
            self.hasPermission = permission
        } else {
            requestUserPermission()
        }
    }

    private func requestUserPermission() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Allow Notchly to Monitor Media Playback?"
            alert.informativeText = "Notchly can display information about your currently playing media. Do you want to allow this?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Allow")
            alert.addButton(withTitle: "Don't Allow")

            let response = alert.runModal()
            self.hasPermission = (response == .alertFirstButtonReturn)
            UserDefaults.standard.set(self.hasPermission, forKey: "MediaPlaybackPermission")

            if self.hasPermission { self.fetchNowPlayingInfo() }
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in self.togglePlayPause(); return .success }
        commandCenter.pauseCommand.addTarget { _ in self.togglePlayPause(); return .success }
        commandCenter.nextTrackCommand.addTarget { _ in self.nextTrack(); return .success }
        commandCenter.previousTrackCommand.addTarget { _ in self.previousTrack(); return .success }
    }

    private func setupNowPlayingObserver() {
        MRMediaRemoteRegisterForNowPlayingNotifications(.main)

        NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")))
            .sink { [weak self] _ in self?.fetchNowPlayingInfo() }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }

        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }

    func fetchNowPlayingInfo() {
        guard hasPermission else { return }

        MRMediaRemoteGetNowPlayingInfo(.main) { [weak self] info in
            guard let self = self else { return }

            if let error = info["kMRMediaRemoteError"] as? NSError, error.code == 35 { return }

            let newInfo = NowPlayingInfo(
                title: info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "",
                artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                duration: info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0,
                elapsedTime: info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0,
                isPlaying: (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) == 1,
                artwork: (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data).flatMap { NSImage(data: $0) },
                appURL: URL(string: "music://")
            )

            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = DispatchWorkItem {
                if self.nowPlaying != newInfo {
                    self.nowPlaying = newInfo
                    self.isPlaying = newInfo.isPlaying
                    self.activePlayer = info["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String ?? "Unknown"
                    self.setThrottledPolling(enabled: !newInfo.isPlaying)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: self.debounceWorkItem!)
        }
    }

    private func setThrottledPolling(enabled: Bool) {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: enabled ? 10 : 2, repeats: true) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }

    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying { playbackManager?.togglePlayPause(isPlaying: true) } else { playbackManager?.togglePlayPause(isPlaying: false) }
        fetchNowPlayingInfo()
    }

    func nextTrack() { playbackManager?.nextTrack(); fetchNowPlayingInfo() }
    func previousTrack() { playbackManager?.previousTrack(); fetchNowPlayingInfo() }
    func seekTo(time: TimeInterval) { playbackManager?.seekTo(time: time); fetchNowPlayingInfo() }
}

// MARK: - Non-failable fallback initializer
extension MediaPlaybackMonitor {
    convenience init?(fallback: Bool) {
        self.init()
        nowPlaying = nil
        isPlaying = false
        activePlayer = "None"
    }

    static func fallback() -> MediaPlaybackMonitor {
        return MediaPlaybackMonitor(fallback: true)!
    }
}
