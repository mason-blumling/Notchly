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

    private var cancellables = Set<AnyCancellable>()
    private var spotifyToken = "YOUR_SPOTIFY_ACCESS_TOKEN"

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

        setupRemoteCommands()
        setupNowPlayingObserver()
        fetchNowPlayingInfo()

        // Periodic refresh as fallback
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            self.fetchNowPlayingInfo()
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            self.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            self.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            self.nextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            self.previousTrack()
            return .success
        }
    }

    private func setupNowPlayingObserver() {
        MRMediaRemoteRegisterForNowPlayingNotifications(.main)

        NotificationCenter.default.publisher(for: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingInfoDidChangeNotification"))
            .merge(with: NotificationCenter.default.publisher(for: NSNotification.Name(rawValue: "kMRMediaRemoteNowPlayingApplicationDidChangeNotification")))
            .sink { [weak self] _ in
                self?.fetchNowPlayingInfo()
            }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }

    func fetchNowPlayingInfo() {
        MRMediaRemoteGetNowPlayingInfo(.main) { [weak self] info in
            guard let self = self else { return }

            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 0
            let elapsedTime = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
            let timestampDate = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date()
            let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let isPlaying = playbackRate == 1
            let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
            let artwork = artworkData != nil ? NSImage(data: artworkData!) : nil

            let adjustedElapsedTime: TimeInterval
            if isPlaying {
                adjustedElapsedTime = elapsedTime + Date().timeIntervalSince(timestampDate)
            } else {
                adjustedElapsedTime = elapsedTime
            }

            DispatchQueue.main.async {
                if title.isEmpty && artist.isEmpty && album.isEmpty {
                    self.nowPlaying = nil
                    self.isPlaying = false
                    self.activePlayer = "Unknown"
                } else {
                    let activeApp = info["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String ?? "Unknown"

                    let appURL: URL? = {
                        switch activeApp.lowercased() {
                        case "music", "apple music":
                            return URL(string: "music://")
                        case "spotify":
                            return URL(string: "spotify://")
                        case "podcasts", "apple podcasts":
                            return URL(string: "podcasts://")
                        default:
                            return nil
                        }
                    }()

                    self.nowPlaying = NowPlayingInfo(
                        title: title,
                        artist: artist,
                        album: album,
                        duration: duration,
                        elapsedTime: adjustedElapsedTime,
                        isPlaying: isPlaying,
                        artwork: artwork,
                        appURL: appURL // ✅ Assign appURL here
                    )

                    self.isPlaying = isPlaying
                    self.activePlayer = activeApp
                }
            }
        }
    }

    // MARK: - Playback Control Methods
    func togglePlayPause() {
        DispatchQueue.main.async {
            self.isPlaying.toggle() // ✅ Instantly update state before sending command
        }
        sendMediaCommand(isPlaying ? 2 : 0)
    }

    func nextTrack() {
        sendMediaCommand(4)
    }

    func previousTrack() {
        sendMediaCommand(5)
    }
    
    func seekTo(time: TimeInterval) {
        MRMediaRemoteSetElapsedTime(time)
    }

    // Add this method alongside existing remote commands
    private func MRMediaRemoteSetElapsedTime(_ elapsedTime: TimeInterval) {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else {
            return
        }
        typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
        let setElapsedTime = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
        setElapsedTime(elapsedTime)
    }

    private func sendMediaCommand(_ command: Int) {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else { return }
        typealias MRMediaRemoteSendCommand = @convention(c) (Int, AnyObject?) -> Void
        let sendCommand = unsafeBitCast(pointer, to: MRMediaRemoteSendCommand.self)
        sendCommand(command, nil)
    }
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
