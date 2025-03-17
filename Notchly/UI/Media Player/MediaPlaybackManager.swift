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
    private let MRMediaRemoteSendCommand: @convention(c) (Int, AnyObject?) -> Void
    private let MRMediaRemoteSetElapsedTime: @convention(c) (Double) -> Void
    
    init?() {
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")) else { return nil }
        
        guard let sendCommandPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString),
              let setElapsedTimePointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else { return nil }
        
        self.mediaRemoteBundle = bundle
        self.MRMediaRemoteSendCommand = unsafeBitCast(sendCommandPointer, to: (@convention(c) (Int, AnyObject?) -> Void).self)
        self.MRMediaRemoteSetElapsedTime = unsafeBitCast(setElapsedTimePointer, to: (@convention(c) (Double) -> Void).self)
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
        MRMediaRemoteSendCommand(command, nil)
    }
}
