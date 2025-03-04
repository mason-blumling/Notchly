//
//  MediaPlaybackMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import Foundation
import Cocoa        // for NSImage
import CoreAudio    // for AudioObject property access

struct NowPlayingInfo {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var sourceApp: String
    var artwork: NSImage?
}

class MediaPlaybackMonitor: ObservableObject {
    @Published var nowPlaying: NowPlayingInfo? = nil
    @Published var isPlaying: Bool = false

    private var MRMediaRemoteGetNowPlayingInfo: ((DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    private var MRMediaRemoteSendCommand: ((Int, Any?) -> Bool)?
    private var MRMediaRemoteSetElapsedTime: ((Double) -> Void)?
    private var MRMediaRemoteRegisterForNowPlayingNotifications: ((DispatchQueue) -> Void)?

    init() {
        print("🎵 MediaPlaybackMonitor INIT ✅")

        // Load MediaRemote functions
        loadMediaRemoteFunctions()

        // Register for media playback notifications
        registerNowPlayingNotifications()
        
        // Ensure NowPlaying info is fetched on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.fetchNowPlayingInfo()
        }

        if MRMediaRemoteRegisterForNowPlayingNotifications != nil {
            MRMediaRemoteRegisterForNowPlayingNotifications?(DispatchQueue.main)
        }

        print("🎵 Notifications Registered ✅")
    }

    private func loadMediaRemoteFunctions() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else {
            print("❌ Failed to load MediaRemote.framework")
            return
        }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            typealias MRNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
            MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(ptr, to: MRNowPlayingInfoFunc.self)
        }
        
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            typealias MRSendCommandFunc = @convention(c) (Int, Any?) -> Bool
            MRMediaRemoteSendCommand = unsafeBitCast(ptr, to: MRSendCommandFunc.self)
        }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
            typealias MRSetElapsedTimeFunc = @convention(c) (Double) -> Void
            MRMediaRemoteSetElapsedTime = unsafeBitCast(ptr, to: MRSetElapsedTimeFunc.self)
        }
        
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void
            MRMediaRemoteRegisterForNowPlayingNotifications = unsafeBitCast(ptr, to: MRRegisterFunc.self)
        }
    }

    private func registerNowPlayingNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchNowPlayingInfo), name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchNowPlayingInfo), name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"), object: nil)
    }

    @objc func fetchNowPlayingInfo() {
        print("🎵 Fetching NowPlaying Info...")

        guard let MRNowPlayingInfo = MRMediaRemoteGetNowPlayingInfo else {
            print("❌ MRMediaRemoteGetNowPlayingInfo is nil")
            return
        }

        MRNowPlayingInfo(DispatchQueue.main) { [weak self] infoDict in
            guard let self = self else { return }
            guard !infoDict.isEmpty else {
                print("🚨 No media info available.")
                return
            }

            let title = infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown Title"
            let artist = infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
            let album = infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "Unknown Album"
            let isPlaying = (infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0
            var sourceApp = infoDict["kMRMediaRemoteNowPlayingClientBundleIdentifier"] as? String ?? "unknown"

            // ✅ Check if we can extract it from client properties
            if sourceApp == "unknown",
               let clientProperties = infoDict["kMRMediaRemoteNowPlayingInfoClientProperties"] as? [String: Any],
               let bundleID = clientProperties["kMRMediaRemoteNowPlayingClientBundleIdentifier"] as? String {
                sourceApp = bundleID
            }

            // 🔥 Special Handling for Apple Music Reporting Issues
            if sourceApp == "com.apple.WebKit.GPU" {
                sourceApp = "com.apple.Music"
            }

            print("🎵 DEBUG: Resolved sourceApp -> \(sourceApp)") // Debugging
            
            var artworkImage: NSImage? = nil
            if let albumArtData = infoDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artworkImage = NSImage(data: albumArtData)
            }

            DispatchQueue.main.async {
                self.nowPlaying = NowPlayingInfo(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: 0,
                    elapsedTime: 0,
                    isPlaying: isPlaying,
                    sourceApp: sourceApp,
                    artwork: artworkImage ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "Default Album Art")
                )
                self.isPlaying = isPlaying
            }
        }
    }
    
    func togglePlayPause() {
        MRMediaRemoteSendCommand?(2, nil)  // kMRTogglePlayPause = 2
    }

    func nextTrack() {
        MRMediaRemoteSendCommand?(4, nil)  // kMRNextTrack = 4
    }

    func previousTrack() {
        MRMediaRemoteSendCommand?(5, nil)  // kMRPreviousTrack = 5
    }

    func seek(to time: TimeInterval) {
        MRMediaRemoteSetElapsedTime?(time)
    }
}
