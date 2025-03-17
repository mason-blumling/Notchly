//
//  MediaPlaybackManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/16/25.
//

import Foundation
import AppKit

class MediaPlaybackManager {
    private let mediaRemoteBundle: CFBundle

    init?() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else { return nil }
        self.mediaRemoteBundle = bundle
    }

    func togglePlayPause(isPlaying: Bool) {
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

    private func sendMediaCommand(_ command: Int) {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else { return }
        typealias MRMediaRemoteSendCommand = @convention(c) (Int, AnyObject?) -> Void
        let sendCommand = unsafeBitCast(pointer, to: MRMediaRemoteSendCommand.self)
        sendCommand(command, nil)
    }
    
    private func MRMediaRemoteSetElapsedTime(_ elapsedTime: TimeInterval) {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
              let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else {
            return
        }
        typealias MRMediaRemoteSetElapsedTimeFunc = @convention(c) (Double) -> Void
        let setElapsedTime = unsafeBitCast(pointer, to: MRMediaRemoteSetElapsedTimeFunc.self)
        setElapsedTime(elapsedTime)
    }
}
