//
//  AudioManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import AVFoundation
import Foundation

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackQueue = DispatchQueue(label: "audioPlayback", qos: .userInitiated)
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silent failure
        }
    }
    
    func playBoomSound(times: Int = 1) {
        if let soundURL = findAudioFile() {
            playAudioFromURL(soundURL, times: times)
        } else {
            playSystemSoundFallback(times: times)
        }
    }
    
    private func findAudioFile() -> URL? {
        if let url = Bundle.main.url(forResource: "boom!thiscontentisnotrecommendedforchildren", withExtension: "mp3") {
            return url
        }
        else if let url = Bundle.main.url(forResource: "boom!thiscontentisnotrecommendedforchildren", withExtension: nil) {
            return url
        }
        else if let url = Bundle.main.url(forResource: "boom!thiscontentisnotrecommendedforchildren", withExtension: "m4a") {
            return url
        }
        else if let url = Bundle.main.url(forResource: "boom!thiscontentisnotrecommendedforchildren", withExtension: "wav") {
            return url
        }
        return nil
    }
    
    private func playAudioFromURL(_ url: URL, times: Int) {
        playbackQueue.async { [weak self] in
            for i in 0..<times {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.play()
                    
                    // Wait for the audio to finish
                    let duration = player.duration
                    Thread.sleep(forTimeInterval: duration + 0.1)
                    
                } catch {
                    // Fallback to system sound for this iteration
                    DispatchQueue.main.async {
                        AudioServicesPlaySystemSound(1016)
                        HapticManager.shared.heavy()
                    }
                    Thread.sleep(forTimeInterval: 0.3)
                }
            }
        }
    }
    
    private func playSystemSoundFallback(times: Int) {
        playbackQueue.async { [weak self] in
            for i in 0..<times {
                DispatchQueue.main.async {
                    AudioServicesPlaySystemSound(1016)
                    HapticManager.shared.heavy()
                }
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }
}