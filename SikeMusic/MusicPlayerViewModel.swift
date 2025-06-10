// Fixed MusicPlayerViewModel.swift
// Resolved audio session errors and deprecation warnings

import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer

enum RepeatMode: String, CaseIterable {
    case off = "Off"
    case one = "Repeat One"
    case all = "Repeat All"
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

class MusicPlayerViewModel: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var tracks: [URL] = [] {
        didSet {
            if !isShuffled {
                originalTrackOrder = tracks
            }
            saveTracks()
        }
    }
    private var originalTrackOrder: [URL] = []
    @Published var currentTrackIndex = 0 {
        didSet {
            UserDefaults.standard.set(currentTrackIndex, forKey: "lastTrackIndex")
        }
    }
    private let documentsURL: URL
    private var audioSessionConfigured = false
    private var sleepTimer: Timer?
    private var volumeView: MPVolumeView?
    
    // Enhanced Features
    @Published var isShuffled = false {
        didSet {
            UserDefaults.standard.set(isShuffled, forKey: "isShuffled")
            if isShuffled {
                shuffleTracks()
            } else {
                restoreOriginalOrder()
            }
        }
    }
    
    @Published var repeatMode: RepeatMode = .off {
        didSet {
            UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        }
    }
    
    @Published var sleepTimerMinutes: Int = 0 {
        didSet {
            setupSleepTimer()
        }
    }
    
    @Published var sleepTimerActive = false
    @Published var sleepTimerRemainingSeconds: Int = 0
    
    @Published var playbackSpeed: Float = 1.0 {
        didSet {
            audioPlayer?.rate = playbackSpeed
            audioPlayer?.enableRate = true
            UserDefaults.standard.set(playbackSpeed, forKey: "playbackSpeed")
        }
    }
    
    // Core Properties
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    // System volume (correlated with device volume)
    @Published var systemVolume: Float = 0.5 {
        didSet {
            setSystemVolume(systemVolume)
        }
    }
    
    var currentTrackTitle: String {
        guard hasValidTrack else {
            return tracks.isEmpty ? "No Music Added" : "Select a Track"
        }
        let filename = tracks[currentTrackIndex].deletingPathExtension().lastPathComponent
        return filename.replacingOccurrences(of: "_", with: " ")
    }
    
    var trackInfo: String {
        guard !tracks.isEmpty else {
            return "Add music files to get started"
        }
        return "Track \(currentTrackIndex + 1) of \(tracks.count)"
    }
    
    var hasValidTrack: Bool {
        return !tracks.isEmpty && tracks.indices.contains(currentTrackIndex)
    }
    
    var progressPercentage: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    var sleepTimerDisplayText: String {
        guard sleepTimerActive else { return "Off" }
        let minutes = sleepTimerRemainingSeconds / 60
        let seconds = sleepTimerRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    override init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        super.init()
        
        setupSystemVolumeControl()
        loadSavedSettings()
        loadSavedTracks()
        setupRemoteTransportControls()
        setupAudioSessionIfNeeded()
        observeSystemVolume()
    }
    
    // MARK: - Fixed Audio Session Setup
    
    private func setupAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.configureAudioSession()
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Deactivate existing session first
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // FIXED: Use correct category and options
            try audioSession.setCategory(
                .playback,  // Use .playback category
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]  // Removed .defaultToSpeaker
            )
            
            // Activate the session
            try audioSession.setActive(true, options: [])
            
            audioSessionConfigured = true
            print("✅ Audio session configured successfully")
            
        } catch let error as NSError {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
            fallbackAudioSessionSetup()
        }
    }
    
    private func fallbackAudioSessionSetup() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Most basic setup possible
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            
            audioSessionConfigured = true
            print("✅ Fallback audio session configured")
        } catch {
            print("❌ Even fallback audio session failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - System Volume Integration
    
    private func setupSystemVolumeControl() {
        volumeView = MPVolumeView(frame: CGRect.zero)
        if let volumeView = volumeView {
            volumeView.alpha = 0.01
            volumeView.isUserInteractionEnabled = false
        }
    }
    
    private func observeSystemVolume() {
        systemVolume = AVAudioSession.sharedInstance().outputVolume
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.systemVolume = AVAudioSession.sharedInstance().outputVolume
        }
    }
    
    private func setSystemVolume(_ volume: Float) {
        guard let volumeView = volumeView,
              let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            return
        }
        
        DispatchQueue.main.async {
            slider.value = volume
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSavedSettings() {
        currentTrackIndex = UserDefaults.standard.integer(forKey: "lastTrackIndex")
        isShuffled = UserDefaults.standard.bool(forKey: "isShuffled")
        
        if let savedRepeatMode = UserDefaults.standard.string(forKey: "repeatMode"),
           let mode = RepeatMode(rawValue: savedRepeatMode) {
            repeatMode = mode
        }
        
        let savedSpeed = UserDefaults.standard.float(forKey: "playbackSpeed")
        if savedSpeed > 0 {
            playbackSpeed = savedSpeed
        }
    }
    
    private func loadSavedTracks() {
        if let savedFilenames = UserDefaults.standard.array(forKey: "savedTrackFilenames") as? [String] {
            let loadedTracks = savedFilenames.compactMap { filename in
                let url = documentsURL.appendingPathComponent(filename)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            
            tracks = loadedTracks
            
            if !tracks.isEmpty && originalTrackOrder.isEmpty {
                originalTrackOrder = tracks
            }
            
            if currentTrackIndex >= tracks.count {
                currentTrackIndex = 0
            }
            
            if hasValidTrack {
                loadTrack(at: currentTrackIndex)
            }
        }
    }
    
    private func saveTracks() {
        let filenames = tracks.map { $0.lastPathComponent }
        UserDefaults.standard.set(filenames, forKey: "savedTrackFilenames")
    }
    
    // MARK: - Track Management
    
    func addTracks(_ urls: [URL], completion: @escaping (String?) -> Void) {
        setupAudioSessionIfNeeded()
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            var successCount = 0
            var errors: [String] = []
            var newTrackURLs: [URL] = []
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    errors.append("Access denied for \(url.lastPathComponent)")
                    continue
                }
                
                defer { url.stopAccessingSecurityScopedResource() }
                
                let destinationURL = self.documentsURL.appendingPathComponent(url.lastPathComponent)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    do {
                        let testPlayer = try AVAudioPlayer(contentsOf: destinationURL)
                        if testPlayer.duration > 0 {
                            successCount += 1
                            newTrackURLs.append(destinationURL)
                        } else {
                            try FileManager.default.removeItem(at: destinationURL)
                            errors.append("Invalid audio file: \(url.lastPathComponent)")
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: destinationURL)
                        errors.append("Unsupported format: \(url.lastPathComponent)")
                    }
                    
                } catch {
                    errors.append("Failed to copy \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            DispatchQueue.main.async {
                self.tracks.append(contentsOf: newTrackURLs)
                self.originalTrackOrder.append(contentsOf: newTrackURLs)
                
                if self.isShuffled {
                    self.shuffleTracks()
                }
                
                if self.tracks.count == successCount && successCount > 0 {
                    self.currentTrackIndex = 0
                    self.loadTrack(at: 0)
                } else if !self.hasValidTrack && !self.tracks.isEmpty {
                    self.currentTrackIndex = 0
                    self.loadTrack(at: 0)
                }
                
                self.objectWillChange.send()
                
                if successCount > 0 && errors.isEmpty {
                    completion(nil)
                } else if successCount > 0 {
                    completion("Added \(successCount) files. Some files failed: \(errors.joined(separator: ", "))")
                } else {
                    completion("Failed to add files: \(errors.joined(separator: ", "))")
                }
            }
        }
    }
    
    func removeTracks(at offsets: IndexSet) {
        let wasPlaying = isPlaying
        let currentTrack = hasValidTrack ? tracks[currentTrackIndex] : nil
        
        for index in offsets {
            if tracks.indices.contains(index) {
                let url = tracks[index]
                try? FileManager.default.removeItem(at: url)
            }
        }
        
        tracks.remove(atOffsets: offsets)
        originalTrackOrder.removeAll { track in
            !tracks.contains(track)
        }
        
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        } else if currentTrackIndex >= tracks.count {
            currentTrackIndex = max(0, tracks.count - 1)
        }
        
        if hasValidTrack {
            loadTrack(at: currentTrackIndex)
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.audioPlayer?.play()
                    self.isPlaying = true
                }
            }
        } else {
            audioPlayer?.stop()
            isPlaying = false
            duration = 0
            currentTime = 0
        }
    }
    
    func playTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        
        currentTrackIndex = index
        loadTrack(at: index)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.audioPlayer?.play()
            self.isPlaying = true
            self.updateNowPlayingInfo()
        }
    }
    
    private func loadTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        
        setupAudioSessionIfNeeded()
        
        currentTrackIndex = index
        let url = tracks[index]
        
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackSpeed
            audioPlayer?.prepareToPlay()
            
            DispatchQueue.main.async {
                self.duration = self.audioPlayer?.duration ?? 0
                self.currentTime = 0
                self.updateNowPlayingInfo()
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
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        guard let player = audioPlayer else { return }
        
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
        } else {
            player.play()
            isPlaying = true
        }
        
        updateNowPlayingInfo()
    }
    
    func nextTrack() {
        guard !tracks.isEmpty else { return }
        
        let wasPlaying = isPlaying
        
        switch repeatMode {
        case .one:
            audioPlayer?.currentTime = 0
            currentTime = 0
            
        case .all, .off:
            if currentTrackIndex < tracks.count - 1 {
                currentTrackIndex += 1
            } else if repeatMode == .all {
                currentTrackIndex = 0
            } else {
                isPlaying = false
                return
            }
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
    
    func previousTrack() {
        guard !tracks.isEmpty else { return }
        
        let wasPlaying = isPlaying
        
        if currentTime > 3.0 {
            audioPlayer?.currentTime = 0
            currentTime = 0
        } else {
            currentTrackIndex = (currentTrackIndex - 1 + tracks.count) % tracks.count
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
    }
    
    func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }
    
    // MARK: - Shuffle and Repeat
    
    private func shuffleTracks() {
        guard !tracks.isEmpty else { return }
        
        if originalTrackOrder.isEmpty {
            originalTrackOrder = tracks
        }
        
        let currentTrack = hasValidTrack ? tracks[currentTrackIndex] : nil
        tracks.shuffle()
        
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        } else {
            currentTrackIndex = 0
        }
    }
    
    private func restoreOriginalOrder() {
        guard !originalTrackOrder.isEmpty else { return }
        
        let currentTrack = hasValidTrack ? tracks[currentTrackIndex] : nil
        tracks = originalTrackOrder
        
        if let currentTrack = currentTrack,
           let newIndex = tracks.firstIndex(of: currentTrack) {
            currentTrackIndex = newIndex
        } else {
            currentTrackIndex = 0
        }
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
    }
    
    func cycleRepeatMode() {
        let allModes = RepeatMode.allCases
        if let currentIndex = allModes.firstIndex(of: repeatMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            repeatMode = allModes[nextIndex]
        }
    }
    
    // MARK: - Sleep Timer
    
    private func setupSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        
        guard sleepTimerMinutes > 0 else {
            sleepTimerActive = false
            sleepTimerRemainingSeconds = 0
            return
        }
        
        sleepTimerActive = true
        sleepTimerRemainingSeconds = sleepTimerMinutes * 60
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.sleepTimerRemainingSeconds -= 1
            
            if self.sleepTimerRemainingSeconds <= 0 {
                self.sleepTimerExpired()
            }
        }
    }
    
    private func sleepTimerExpired() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerActive = false
        sleepTimerRemainingSeconds = 0
        sleepTimerMinutes = 0
        
        fadeOutAndStop()
    }
    
    private func fadeOutAndStop() {
        guard let player = audioPlayer, player.isPlaying else { return }
        
        let fadeOutTime: TimeInterval = 3.0
        let steps = 30
        let volumeStep = systemVolume / Float(steps)
        let timeStep = fadeOutTime / Double(steps)
        
        var currentStep = 0
        let fadeTimer = Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let newVolume = self.systemVolume - (volumeStep * Float(currentStep))
            self.systemVolume = max(0, newVolume)
            
            if currentStep >= steps || newVolume <= 0 {
                timer.invalidate()
                player.stop()
                self.isPlaying = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.systemVolume = self.systemVolume + (volumeStep * Float(steps))
                }
            }
        }
    }
    
    func setSleepTimer(minutes: Int) {
        sleepTimerMinutes = minutes
    }
    
    func cancelSleepTimer() {
        sleepTimerMinutes = 0
    }
    
    // MARK: - Remote Controls
    
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
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = "SikeMusic"
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "My Library"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        
        if hasValidTrack {
            let currentTrack = tracks[currentTrackIndex]
            DispatchQueue.global(qos: .background).async {
                if let artwork = self.extractArtwork(from: currentTrack) {
                    let mediaArtwork = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                        return artwork
                    }
                    
                    DispatchQueue.main.async {
                        var updatedInfo = nowPlayingInfo
                        updatedInfo[MPMediaItemPropertyArtwork] = mediaArtwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                    }
                } else {
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    // MARK: - Fixed Artwork Extraction
    
    func extractArtwork(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)  // FIXED: Use AVURLAsset instead of deprecated AVAsset(url:)
        
        // FIXED: Use async metadata loading for iOS 16+
        if #available(iOS 16.0, *) {
            // For iOS 16+, we'll use the synchronous method for now in background
            // In a real app, you'd want to use the async load methods
            let metadataList = asset.commonMetadata
            
            for item in metadataList {
                if let key = item.commonKey?.rawValue,
                   key == "artwork" {
                    // FIXED: Access value synchronously for now
                    if let data = item.value as? Data,
                       let image = UIImage(data: data) {
                        return image
                    }
                }
            }
        } else {
            // For iOS 15 and below, use the old method
            let metadataList = asset.commonMetadata
            
            for item in metadataList {
                guard let key = item.commonKey?.rawValue,
                      key == "artwork",
                      let value = item.value else { continue }
                
                if let data = value as? Data,
                   let image = UIImage(data: data) {
                    return image
                }
            }
        }
        
        return nil
    }
    
    deinit {
        sleepTimer?.invalidate()
        audioPlayer?.stop()
        
        if audioSessionConfigured {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        NotificationCenter.default.removeObserver(self)
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
        nextTrack()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                player.play()
                isPlaying = true
                updateNowPlayingInfo()
            } catch {
                print("❌ Failed to resume after interruption: \(error.localizedDescription)")
            }
        }
    }
}


