//
//  NowPlayingManager.swift
//  Notchly
//
//  Created by Mason Blumling on 3/2/25.
//

import Foundation
import Cocoa        // for NSImage
import CoreAudio    // for AudioObject property access

// Structure to hold now-playing info
struct NowPlayingInfo {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var sourceApp: String       // bundle identifier of source (e.g., com.apple.Music, com.spotify.client)
    var artwork: NSImage?       // album artwork if available
}

class MediaPlaybackMonitor: ObservableObject { // ✅ Make it Observable
    // ✅ @Published properties to update UI dynamically
    @Published var nowPlaying: NowPlayingInfo? = nil
    @Published var isPlaying: Bool = false
    
    // MARK: - Properties and function pointers for MediaRemote
    private var MRMediaRemoteGetNowPlayingInfo: ((DispatchQueue, @escaping ([String: Any]) -> Void) -> Void)?
    private var MRMediaRemoteSendCommand: ((Int, Any?) -> Bool)?
    private var MRMediaRemoteSetElapsedTime: ((Double) -> Void)?
    private var MRNowPlayingClientGetBundleIdentifier: ((AnyObject?) -> String)?
    
    // Tracking the current NowPlaying info
    private(set) var currentInfo: NowPlayingInfo?
    
    // CoreAudio: default output device ID
    private var defaultOutputDevice: AudioDeviceID = 0
    
    init() {
        // Register for notifications when media playback changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateNowPlayingInfo),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(updateNowPlayingInfo),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
        
        // Load MediaRemote framework and get function pointers
        loadMediaRemoteFunctions()
        // Get default audio output device
        initDefaultAudioDevice()
        // Register for distributed notifications from Music and Spotify
        registerNowPlayingNotifications()
        
        // ✅ Poll for updates every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateNowPlayingInfo()
        }
    }
    
    // MARK: - MediaRemote loading
    private func loadMediaRemoteFunctions() {
        // Path to MediaRemote private framework
        guard let bundleURL = URL(string: "/System/Library/PrivateFrameworks/MediaRemote.framework") else {
            return
        }
        if let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) {
            // MRMediaRemoteGetNowPlayingInfo
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                typealias MRNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
                MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(ptr, to: MRNowPlayingInfoFunc.self)
            }
            // MRMediaRemoteSendCommand
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
                typealias MRSendCommandFunc = @convention(c) (Int, Any?) -> Bool
                MRMediaRemoteSendCommand = unsafeBitCast(ptr, to: MRSendCommandFunc.self)
            }
            // MRMediaRemoteSetElapsedTime
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
                typealias MRSetElapsedTimeFunc = @convention(c) (Double) -> Void
                MRMediaRemoteSetElapsedTime = unsafeBitCast(ptr, to: MRSetElapsedTimeFunc.self)
            }
            // MRNowPlayingClientGetBundleIdentifier
            if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRNowPlayingClientGetBundleIdentifier" as CFString) {
                typealias MRGetBundleIdFunc = @convention(c) (AnyObject?) -> String
                MRNowPlayingClientGetBundleIdentifier = unsafeBitCast(ptr, to: MRGetBundleIdFunc.self)
            }
        }
    }
    
    // MARK: - CoreAudio device monitoring
    private func initDefaultAudioDevice() {
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID: AudioDeviceID = 0
        // Property address for default output device
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                               &address,
                                               0, nil,
                                               &size, &deviceID)
        if status == kAudioHardwareNoError {
            self.defaultOutputDevice = deviceID
            // Add listener to detect when device starts/stops running
            var runAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(defaultOutputDevice, &runAddr, DispatchQueue.global(qos: .background)) { [weak self] _, _ in
                guard let strongSelf = self else { return }
                let isRunning = strongSelf.isAudioRunning()
                // If audio started or stopped, we could handle that event.
                print("System audio running: \(isRunning)")
                // For example, if no audio is running, we might reset now-playing info.
            }
        }
    }
    
    /// Check if the default output device is currently running (i.e., audio is active)
    func isAudioRunning() -> Bool {
        var size = UInt32(MemoryLayout<UInt32>.size)
        var isRunning: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(defaultOutputDevice, &address, 0, nil, &size, &isRunning)
        if status == noErr {
            return isRunning != 0
        }
        return false
    }
    
    // MARK: - Distributed Notifications for track changes
    private func registerNowPlayingNotifications() {
        let center = DistributedNotificationCenter.default()
        // Apple Music (iTunes) notifications
        center.addObserver(self, selector: #selector(handleNowPlayingNotification(_:)),
                           name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)
        // Spotify notifications
        center.addObserver(self, selector: #selector(handleNowPlayingNotification(_:)),
                           name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        // (If needed, add Podcasts if it had one, but it doesn't publicly. Handled via MediaRemote alone.)
    }
    
    @objc private func handleNowPlayingNotification(_ notification: Notification) {
        // When we get a notification from Spotify or Music, fetch unified now-playing info
        updateNowPlayingInfo()
    }
    
    // MARK: - Now Playing Info update
    /// Fetches the now-playing info via MediaRemote and updates `currentInfo`
    @objc func updateNowPlayingInfo() {
        guard let MRNowPlayingInfo = MRMediaRemoteGetNowPlayingInfo else { return }

        MRNowPlayingInfo(DispatchQueue.main) { [weak self] infoDict in
            guard let self = self else { return }

            let title = infoDict["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown Title"
            let artist = infoDict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
            let album = infoDict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "Unknown Album"
            let isPlaying = (infoDict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0) > 0

            var artworkImage: NSImage? = nil
            if let albumArtData = infoDict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artworkImage = NSImage(data: albumArtData)
            }

            // ✅ Update @Published properties
            DispatchQueue.main.async {
                self.nowPlaying = NowPlayingInfo(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: 0, // Can be updated later if needed
                    elapsedTime: 0, // Can be updated later if needed
                    isPlaying: isPlaying,
                    sourceApp: "Music",
                    artwork: artworkImage
                )
                self.isPlaying = isPlaying
            }
        }
    }
    
    // MARK: - Playback control methods
    func play() {
        sendMediaRemoteCommand(command: 0)  // kMRPlay = 0
    }
    func pause() {
        sendMediaRemoteCommand(command: 1)  // kMRPause = 1
    }
    func togglePlayPause() {
        sendMediaRemoteCommand(command: 2)  // kMRTogglePlayPause = 2
    }
    func nextTrack() {
        sendMediaRemoteCommand(command: 4)  // kMRNextTrack = 4
    }
    func previousTrack() {
        sendMediaRemoteCommand(command: 5)  // kMRPreviousTrack = 5
    }
    func seek(to time: TimeInterval) {
        // Set playback position to specified time (in seconds)
        MRMediaRemoteSetElapsedTime?(time)
    }
    
    private func sendMediaRemoteCommand(command: Int) {
        guard let sendCommand = MRMediaRemoteSendCommand else { return }
        _ = sendCommand(command, nil)
        // The command will be directed to the current now-playing app as per system behavior
    }
    
    // MARK: - Volume control
    func setVolume(percent: Int) {
        // Clamp volume 0...100
        let vol = max(0, min(100, percent))
        // Determine target app from current source
        guard let sourceAppBundle = currentInfo?.sourceApp else { return }
        // Map bundle ID to application name for AppleScript
        var appName: String? = nil
        if sourceAppBundle.contains("spotify") {
            appName = "Spotify"
        } else if sourceAppBundle.contains("Music") {
            appName = "Music"
        } else if sourceAppBundle.contains("podcasts") {
            appName = "Podcasts"
        }
        guard let targetApp = appName else {
            // If unknown app, fallback to system volume? (or do nothing)
            setSystemVolume(percent: vol)
            return
        }
        let scriptSource = "tell application \"\(targetApp)\" to set sound volume to \(vol)"
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorDict: NSDictionary? = nil
            appleScript.executeAndReturnError(&errorDict)
            if let error = errorDict {
                print("AppleScript volume set error: \(error)")
            }
        }
    }
    
    /// Fallback: set system output volume (0-100)
    private func setSystemVolume(percent: Int) {
        let vol = Float(percent) / 100.0
        var defaultDeviceID = defaultOutputDevice

        if defaultDeviceID == 0 {
            // Get default device if not set
            initDefaultAudioDevice()
            defaultDeviceID = defaultOutputDevice
        }

        var volume = vol
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar, // ✅ FIXED: Correct property name
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            defaultDeviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float>.size),
            &volume
        )

        if status != noErr {
            print("❌ Failed to set system volume.")
        }
    }
    
    deinit {
        // Remove notification observers
        DistributedNotificationCenter.default().removeObserver(self)

        // Remove CoreAudio listener
        var runAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // ✅ Fix: Pass the correct argument
        AudioObjectRemovePropertyListenerBlock(defaultOutputDevice, &runAddr, DispatchQueue.global(qos: .background), {_,_ in })
    }
}
