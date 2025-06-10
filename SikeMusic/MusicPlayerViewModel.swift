// MusicPlayerViewModel.swift
// This handles all the audio playback logic

import Foundation
import AVFoundation
import SwiftUI

class MusicPlayerViewModel: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var tracks: [URL] = []
    private var currentTrackIndex = 0
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.7 {
        didSet {
            audioPlayer?.volume = volume
        }
    }
    
    var currentTrackTitle: String {
        guard !tracks.isEmpty, tracks.indices.contains(currentTrackIndex) else {
            return "No track selected"
        }
        return tracks[currentTrackIndex].deletingPathExtension().lastPathComponent
    }
    
    var trackInfo: String {
        guard !tracks.isEmpty else {
            return "Add music to start"
        }
        return "Track \(currentTrackIndex + 1) of \(tracks.count)"
    }
    
    override init() {
        super.init()
        setupAudioSession()
        loadSavedTracks()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func loadSavedTracks() {
        if let savedURLs = UserDefaults.standard.array(forKey: "savedTracks") as? [String] {
            tracks = savedURLs.compactMap { URL(string: $0) }
            if !tracks.isEmpty {
                loadTrack(at: 0)
            }
        }
    }
    
    private func saveTracks() {
        let urlStrings = tracks.map { $0.absoluteString }
        UserDefaults.standard.set(urlStrings, forKey: "savedTracks")
    }
    
    func addTracks(_ urls: [URL]) {
        // Start accessing security-scoped resources
        let newTracks = urls.compactMap { url -> URL? in
            guard url.startAccessingSecurityScopedResource() else { return nil }
            
            // Copy file to app's documents directory for persistent access
            let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                        in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                // Copy the file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                url.stopAccessingSecurityScopedResource()
                return destinationURL
            } catch {
                print("Error copying file: \(error)")
                url.stopAccessingSecurityScopedResource()
                return nil
            }
        }
        
        tracks.append(contentsOf: newTracks)
        saveTracks()
        
        if tracks.count == newTracks.count {
            loadTrack(at: 0)
        }
    }
    
    private func loadTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        
        currentTrackIndex = index
        let url = tracks[index]
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("Error loading track: \(error)")
        }
    }
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        loadTrack(at: currentTrackIndex)
        audioPlayer?.play()
        isPlaying = true
    }
    
    func previousTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
        loadTrack(at: currentTrackIndex)
        audioPlayer?.play()
        isPlaying = true
    }
    
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        let newTime = player.duration * progress
        player.currentTime = newTime
        currentTime = newTime
    }
    
    func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }
}

// AVAudioPlayerDelegate
extension MusicPlayerViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            nextTrack()
        }
    }
}


