// MusicPlayerViewModel.swift
// Debug version with extensive logging

import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer

class MusicPlayerViewModel: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var tracks: [URL] = [] {
        didSet {
            print("🎵 Tracks updated: \(tracks.count) tracks")
            tracks.forEach { track in
                print("   - \(track.lastPathComponent)")
            }
        }
    }
    private var currentTrackIndex = 0
    private let documentsURL: URL
    private var audioSessionConfigured = false
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.7 {
        didSet {
            audioPlayer?.volume = volume
            UserDefaults.standard.set(volume, forKey: "savedVolume")
        }
    }
    
    var currentTrackTitle: String {
        guard hasValidTrack else {
            let title = tracks.isEmpty ? "No Music Added" : "Select a Track"
            print("🎵 Current track title: \(title)")
            return title
        }
        let filename = tracks[currentTrackIndex].deletingPathExtension().lastPathComponent
        let title = filename.replacingOccurrences(of: "_", with: " ")
        print("🎵 Current track title: \(title)")
        return title
    }
    
    var trackInfo: String {
        guard !tracks.isEmpty else {
            return "Add music files to get started"
        }
        return "Track \(currentTrackIndex + 1) of \(tracks.count)"
    }
    
    var hasValidTrack: Bool {
        let valid = !tracks.isEmpty && tracks.indices.contains(currentTrackIndex)
        print("🎵 Has valid track: \(valid), tracks count: \(tracks.count), current index: \(currentTrackIndex)")
        return valid
    }
    
    var progressPercentage: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    override init() {
        // Get documents directory
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        print("📁 Documents URL: \(documentsURL.path)")
        
        super.init()
        loadSavedSettings()
        loadSavedTracks()
        setupRemoteTransportControls()
        setupAudioSessionIfNeeded()
    }
    
    private func setupAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.configureAudioSession()
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, try to deactivate any existing session
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Configure the audio session for playback
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            
            // Activate the audio session
            try audioSession.setActive(true, options: [])
            
            audioSessionConfigured = true
            print("✅ Audio session configured successfully")
            
        } catch let error as NSError {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
            print("Error code: \(error.code), Domain: \(error.domain)")
            
            // Fallback: Try basic configuration
            fallbackAudioSessionSetup()
        }
    }
    
    private func fallbackAudioSessionSetup() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Try the most basic setup
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            
            audioSessionConfigured = true
            print("✅ Fallback audio session configured")
            
        } catch {
            print("❌ Even fallback audio session failed: \(error.localizedDescription)")
            // Continue anyway - some audio might still work
        }
    }
    
    private func loadSavedSettings() {
        // Load saved volume
        let savedVolume = UserDefaults.standard.float(forKey: "savedVolume")
        if savedVolume > 0 {
            volume = savedVolume
        }
        
        // Load last played track index
        currentTrackIndex = UserDefaults.standard.integer(forKey: "lastTrackIndex")
        print("📱 Loaded settings - Volume: \(volume), Track Index: \(currentTrackIndex)")
    }
    
    private func loadSavedTracks() {
        print("📱 Loading saved tracks...")
        
        if let savedFilenames = UserDefaults.standard.array(forKey: "savedTrackFilenames") as? [String] {
            print("📱 Found saved filenames: \(savedFilenames)")
            
            var loadedTracks: [URL] = []
            for filename in savedFilenames {
                let url = documentsURL.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    loadedTracks.append(url)
                    print("✅ Found file: \(filename)")
                } else {
                    print("❌ Missing file: \(filename) at \(url.path)")
                }
            }
            
            tracks = loadedTracks
            print("📱 Loaded \(tracks.count) tracks total")
            
            // Validate current track index
            if currentTrackIndex >= tracks.count {
                currentTrackIndex = 0
                print("📱 Reset track index to 0")
            }
            
            if hasValidTrack {
                print("📱 Loading track at index \(currentTrackIndex)")
                loadTrack(at: currentTrackIndex)
            } else {
                print("📱 No valid track to load")
            }
        } else {
            print("📱 No saved tracks found in UserDefaults")
        }
        
        // Debug: List all files in documents directory
        listDocumentsDirectory()
    }
    
    private func listDocumentsDirectory() {
        print("📁 Documents directory contents:")
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: documentsURL.path)
            if contents.isEmpty {
                print("   (empty)")
            } else {
                for file in contents {
                    print("   - \(file)")
                }
            }
        } catch {
            print("   Error reading directory: \(error)")
        }
    }
    
    private func saveTracks() {
        let filenames = tracks.map { $0.lastPathComponent }
        UserDefaults.standard.set(filenames, forKey: "savedTrackFilenames")
        UserDefaults.standard.set(currentTrackIndex, forKey: "lastTrackIndex")
        print("💾 Saved tracks: \(filenames)")
    }
    
    func addTracks(_ urls: [URL], completion: @escaping (String?) -> Void) {
        print("🎵 Adding \(urls.count) tracks...")
        
        // Ensure audio session is configured before adding tracks
        setupAudioSessionIfNeeded()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            var successCount = 0
            var errors: [String] = []
            var newTrackURLs: [URL] = []
            
            for url in urls {
                print("🎵 Processing: \(url.lastPathComponent)")
                
                guard url.startAccessingSecurityScopedResource() else {
                    let error = "Access denied for \(url.lastPathComponent)"
                    errors.append(error)
                    print("❌ \(error)")
                    continue
                }
                
                defer { url.stopAccessingSecurityScopedResource() }
                
                let destinationURL = self.documentsURL.appendingPathComponent(url.lastPathComponent)
                print("🎵 Destination: \(destinationURL.path)")
                
                do {
                    // Remove existing file if it exists
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                        print("🗑️ Removed existing file")
                    }
                    
                    // Copy the file
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    print("✅ File copied successfully")
                    
                    // Verify the file is a valid audio file
                    do {
                        let testPlayer = try AVAudioPlayer(contentsOf: destinationURL)
                        if testPlayer.duration > 0 {
                            successCount += 1
                            newTrackURLs.append(destinationURL)
                            print("✅ Verified audio file (duration: \(testPlayer.duration)s)")
                        } else {
                            try FileManager.default.removeItem(at: destinationURL)
                            let error = "Invalid audio file: \(url.lastPathComponent)"
                            errors.append(error)
                            print("❌ \(error)")
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: destinationURL)
                        let errorMsg = "Unsupported format: \(url.lastPathComponent)"
                        errors.append(errorMsg)
                        print("❌ \(errorMsg) - \(error)")
                    }
                    
                } catch {
                    let errorMsg = "Failed to copy \(url.lastPathComponent): \(error.localizedDescription)"
                    errors.append(errorMsg)
                    print("❌ \(errorMsg)")
                }
            }
            
            DispatchQueue.main.async {
                print("🎵 Processing complete. Success: \(successCount), Errors: \(errors.count)")
                
                // Add new tracks to existing tracks
                self.tracks.append(contentsOf: newTrackURLs)
                self.saveTracks()
                
                // If this is the first batch of tracks, load the first one
                if self.tracks.count == successCount && successCount > 0 {
                    print("🎵 Loading first track...")
                    self.currentTrackIndex = 0
                    self.loadTrack(at: 0)
                } else if !self.hasValidTrack && !self.tracks.isEmpty {
                    // If we had no valid track before but now we do
                    print("🎵 Loading first available track...")
                    self.currentTrackIndex = 0
                    self.loadTrack(at: 0)
                }
                
                // Force UI update
                self.objectWillChange.send()
                
                // Return appropriate message
                if successCount > 0 && errors.isEmpty {
                    completion(nil) // Success
                } else if successCount > 0 {
                    completion("Added \(successCount) files. Some files failed: \(errors.joined(separator: ", "))")
                } else {
                    completion("Failed to add files: \(errors.joined(separator: ", "))")
                }
                
                print("🎵 Final state - Tracks: \(self.tracks.count), Current index: \(self.currentTrackIndex)")
            }
        }
    }
    
    private func loadTrack(at index: Int) {
        guard tracks.indices.contains(index) else {
            print("❌ Invalid track index: \(index) (tracks count: \(tracks.count))")
            return
        }
        
        print("🎵 Loading track at index \(index): \(tracks[index].lastPathComponent)")
        
        // Ensure audio session is ready
        setupAudioSessionIfNeeded()
        
        currentTrackIndex = index
        let url = tracks[index]
        
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            
            DispatchQueue.main.async {
                self.duration = self.audioPlayer?.duration ?? 0
                self.currentTime = 0
                self.updateNowPlayingInfo()
                self.saveTracks()
                
                print("✅ Track loaded successfully - Duration: \(self.duration)s")
                
                // Force UI update
                self.objectWillChange.send()
            }
        } catch {
            print("❌ Error loading track: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.duration = 0
                self.currentTime = 0
            }
        }
    }
    
    func togglePlayPause() {
        print("🎵 Toggle play/pause - Current state: \(isPlaying ? "playing" : "paused")")
        
        guard let player = audioPlayer else {
            print("❌ No audio player available")
            return
        }
        
        // Ensure audio session is active before playing
        if !player.isPlaying {
            setupAudioSessionIfNeeded()
            
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("❌ Failed to activate audio session for playback: \(error.localizedDescription)")
            }
        }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            print("⏸️ Paused")
        } else {
            let success = player.play()
            isPlaying = success
            print(success ? "▶️ Playing" : "❌ Failed to start playback")
        }
        
        updateNowPlayingInfo()
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        let wasPlaying = isPlaying
        currentTrackIndex = (currentTrackIndex + 1) % tracks.count
        print("⏭️ Next track - Index: \(currentTrackIndex)")
        loadTrack(at: currentTrackIndex)
        
        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioPlayer?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
            }
        }
    }
    
    func previousTrack() {
        guard !tracks.isEmpty else { return }
        let wasPlaying = isPlaying
        
        // If more than 3 seconds into the song, restart current track
        if currentTime > 3.0 {
            audioPlayer?.currentTime = 0
            currentTime = 0
            print("⏮️ Restart current track")
        } else {
            currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
            print("⏮️ Previous track - Index: \(currentTrackIndex)")
            loadTrack(at: currentTrackIndex)
        }
        
        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioPlayer?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
            }
        }
    }
    
    func seek(to progress: Double) {
        guard let player = audioPlayer, duration > 0 else { return }
        let newTime = duration * progress
        player.currentTime = newTime
        currentTime = newTime
        updateNowPlayingInfo()
        print("⏯️ Seeked to: \(newTime)s")
    }
    
    func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }
    
    // MARK: - Now Playing Info (Lock Screen Controls)
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            self.audioPlayer?.currentTime = event.positionTime
            self.currentTime = event.positionTime
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = "SikeMusic"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Cleanup
    
    deinit {
        audioPlayer?.stop()
        if audioSessionConfigured {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension MusicPlayerViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            nextTrack()
        } else {
            isPlaying = false
            updateNowPlayingInfo()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        nextTrack() // Try to play next track
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
            player.play()
            isPlaying = true
            updateNowPlayingInfo()
        }
    }
}


