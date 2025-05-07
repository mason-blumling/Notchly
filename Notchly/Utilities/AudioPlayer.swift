//
//  AudioPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 5/6/25.
//

import AVFoundation

class AudioPlayer {
    // Singleton pattern for shared instance across the app
    static let shared = AudioPlayer()
    
    private var player: AVAudioPlayer?
    
    // Prevent external instantiation
    private init() {}
    
    /// Play a sound file once
    func playSound(named name: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            print("🔊 Error: Could not find sound file \(name).\(fileExtension)")
            return
        }
        
        do {
            // Create and configure audio player
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("🔊 Error playing sound: \(error.localizedDescription)")
        }
    }
    
    /// Stop currently playing sound
    func stopSound() {
        player?.stop()
    }
}
