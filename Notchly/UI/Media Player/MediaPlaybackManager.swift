//
//  MediaPlaybackManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/16/25.
//

import Foundation
import AppKit

final class MediaPlaybackManager {
    private let mediaRemoteBundle: CFBundle

    init?() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        else { return nil }
        
        self.mediaRemoteBundle = bundle
    }

    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteGetNowPlayingInfo" as CFString
        ) else {
            completion(nil)
            return
        }

        typealias MRMediaRemoteGetNowPlayingInfoFunc =
            @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        let getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunc.self)

        let fetchStart = Date()
        getNowPlayingInfo(.global()) { infoDict in
            // Discard stale responses if more than 1s has passed
            guard Date().timeIntervalSince(fetchStart) < 1.0 else {
                completion(nil)
                return
            }

            let playbackRate = infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let elapsedTime = infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
            let timestamp = infoDict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date()

            // If playing, add the time since the timestamp to the elapsedTime
            let adjustedElapsedTime = elapsedTime + (playbackRate == 1
                                                     ? Date().timeIntervalSince(timestamp)
                                                     : 0)

            let nowPlayingInfo = NowPlayingInfo(
                title: infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "",
                artist: infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album: infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                duration: infoDict["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 1,
                elapsedTime: adjustedElapsedTime,
                isPlaying: playbackRate == 1,
                artwork: (infoDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data)
                    .flatMap { NSImage(data: $0) },
                appName: infoDict["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String
                    ?? "Unknown"
            )

            completion(nowPlayingInfo)
        }
    }

    func togglePlayPause(isPlaying: Bool) {
        // isPlaying==true means we want the system to be in "playing" state,
        // so we call command=0 (pause) if it's already playing, or 2 (play) if not.
        sendMediaCommand(isPlaying ? 0 : 2)
    }

    func nextTrack() {
        sendMediaCommand(4)
    }

    func previousTrack() {
        sendMediaCommand(5)
    }

    func seekTo(time: TimeInterval) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteSetElapsedTime" as CFString
        ) else { return }

        typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
        let setElapsedTime = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
        setElapsedTime(time)
    }

    private func sendMediaCommand(_ command: Int) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteSendCommand" as CFString
        ) else { return }

        typealias MRMediaRemoteSendCommand = @convention(c) (Int, AnyObject?) -> Void
        let sendCommand = unsafeBitCast(pointer, to: MRMediaRemoteSendCommand.self)
        sendCommand(command, nil)
    }
}
