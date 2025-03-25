//
//  MediaPlaybackManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/16/25.
//

import Foundation
import AppKit

/// Provides low-level access to Apple's private MediaRemote framework,
/// enabling commands such as fetching now-playing information, toggling play/pause,
/// skipping tracks, and seeking within a track.
final class MediaPlaybackManager {
    // MARK: - Properties
    private let mediaRemoteBundle: CFBundle

    // MARK: - Initialization
    init?() {
        // Attempt to create a CFBundle for the private MediaRemote framework.
        guard let bundle = CFBundleCreate(kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
        else {
            return nil
        }
        
        self.mediaRemoteBundle = bundle
    }

    // MARK: - Now Playing Info Fetching
    /// Retrieves the current now-playing information from the system.
    /// - Parameter completion: A closure called with a `NowPlayingInfo?` object.
    func getNowPlayingInfo(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteGetNowPlayingInfo" as CFString
        ) else {
            completion(nil)
            return
        }
        
        typealias MRMediaRemoteGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
        let getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunc.self)
        
        let fetchStart = Date()
        getNowPlayingInfo(.global()) { infoDict in
            // Discard responses if more than 1 second has passed since the call.
            guard Date().timeIntervalSince(fetchStart) < 1.0 else {
                completion(nil)
                return
            }
            
            // Extract media info from the dictionary.
            let playbackRate = infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
            let elapsedTime = infoDict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval ?? 0
            let timestamp = infoDict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date()
            
            // Adjust elapsed time based on the time since the timestamp if playing.
            let adjustedElapsedTime = elapsedTime + (playbackRate == 1 ? Date().timeIntervalSince(timestamp) : 0)
            
            let nowPlayingInfo = NowPlayingInfo(
                title: infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "",
                artist: infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
                album: infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
                duration: infoDict["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval ?? 1,
                elapsedTime: adjustedElapsedTime,
                isPlaying: playbackRate == 1,
                artwork: (infoDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data).flatMap { NSImage(data: $0) },
                appName: infoDict["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String ?? "Unknown"
            )
            
            completion(nowPlayingInfo)
        }
    }
    
    // MARK: - Playback Control Methods
    
    /// Toggles play/pause state.
    /// - Parameter isPlaying: If true, indicates that the system should be in the "playing" state.
    func togglePlayPause(isPlaying: Bool) {
        // When isPlaying is true, we want to pause if it's already playing (command 0),
        // or play if it's paused (command 2).
        sendMediaCommand(isPlaying ? 0 : 2)
    }
    
    /// Skips to the next track.
    func nextTrack() {
        sendMediaCommand(4)
    }
    
    /// Skips to the previous track.
    func previousTrack() {
        sendMediaCommand(5)
    }
    
    /// Seeks to a specified time within the current track.
    /// - Parameter time: The target time in seconds.
    func seekTo(time: TimeInterval) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteSetElapsedTime" as CFString
        ) else { return }
        
        typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
        let setElapsedTime = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
        setElapsedTime(time)
    }
    
    // MARK: - Private Helper: Send Media Command
    /// Sends a media command to the system via MediaRemote.
    /// - Parameter command: An integer command code.
    private func sendMediaCommand(_ command: Int) {
        guard let pointer = CFBundleGetFunctionPointerForName(
            mediaRemoteBundle, "MRMediaRemoteSendCommand" as CFString
        ) else { return }
        
        typealias MRMediaRemoteSendCommand = @convention(c) (Int, AnyObject?) -> Void
        let sendCommand = unsafeBitCast(pointer, to: MRMediaRemoteSendCommand.self)
        sendCommand(command, nil)
    }
}
