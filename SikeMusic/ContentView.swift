//
//  ContentView.swift
//  SikeMusic - Complete Fixed Version
//
//  Fixed all deprecation warnings and issues
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import MediaPlayer

struct ContentView: View {
    @StateObject private var player = MusicPlayerViewModel()
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPlayer = false
    @State private var showingIconSelector = false
    @State private var searchText = ""
    
    var filteredTracks: [URL] {
        if searchText.isEmpty {
            return player.tracks
        } else {
            return player.tracks.filter { track in
                track.deletingPathExtension().lastPathComponent
                    .localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f1e")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with app icon selector
                    HStack {
                        Button(action: { showingIconSelector = true }) {
                            Image(systemName: "app.gift")
                                .font(.title2)
                                .foregroundColor(Color(hex: "667eea"))
                        }
                        
                        Spacer()
                        
                        Text("SikeMusic")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        Button(action: { isImporting = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(hex: "667eea"))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Search songs...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 15)
                    
                    // Songs list or empty state
                    if filteredTracks.isEmpty {
                        if player.tracks.isEmpty {
                            // Empty state - no songs
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                VStack(spacing: 10) {
                                    Text("No Music Yet")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text("Add your favorite songs to get started")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: { isImporting = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Your First Song")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 15)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(25)
                                }
                                .padding(.top, 20)
                                
                                Spacer()
                            }
                            .padding()
                        } else {
                            // No search results
                            VStack(spacing: 15) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text("No results found")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                            }
                        }
                    } else {
                        // Songs list
                        List {
                            ForEach(Array(filteredTracks.enumerated()), id: \.offset) { index, track in
                                let actualIndex = player.tracks.firstIndex(of: track) ?? index
                                SongRow(
                                    track: track,
                                    isCurrentTrack: actualIndex == player.currentTrackIndex,
                                    isPlaying: player.isPlaying && actualIndex == player.currentTrackIndex,
                                    onTap: {
                                        if actualIndex == player.currentTrackIndex {
                                            showingPlayer = true
                                        } else {
                                            player.playTrack(at: actualIndex)
                                            showingPlayer = true
                                        }
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deleteTracks)
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                    }
                    
                    // Mini player (when music is playing)
                    if player.hasValidTrack && !showingPlayer {
                        MiniPlayer(player: player) {
                            showingPlayer = true
                        }
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPlayer) {
            FullPlayerView(player: player)
        }
        .sheet(isPresented: $showingIconSelector) {
            AppIconSelectorView()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let files):
                player.addTracks(files) { error in
                    if let error = error {
                        errorMessage = error
                        showingError = true
                    }
                }
            case .failure(let error):
                errorMessage = "Error selecting files: \(error.localizedDescription)"
                showingError = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if player.isPlaying {
                player.updateProgress()
            }
        }
    }
    
    private func deleteTracks(at offsets: IndexSet) {
        player.removeTracks(at: offsets)
    }
}

// MARK: - Song Row Component

struct SongRow: View {
    let track: URL
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    @State private var artwork: UIImage?
    
    var trackName: String {
        track.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Album artwork or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    if let artwork = artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Playing indicator overlay
                    if isCurrentTrack && isPlaying {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(trackName)
                        .font(.body)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                        .foregroundColor(isCurrentTrack ? Color(hex: "667eea") : .white)
                        .lineLimit(1)
                    
                    Text("SikeMusic")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Play/pause indicator
                if isCurrentTrack {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "667eea"))
                } else {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentTrack ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        DispatchQueue.global(qos: .background).async {
            // Use AVURLAsset instead of deprecated AVAsset(url:)
            let asset = AVURLAsset(url: track)
            let metadataList = asset.commonMetadata
            
            for item in metadataList {
                guard let key = item.commonKey?.rawValue,
                      key == "artwork" else { continue }
                
                // Handle metadata access for different iOS versions
                if let data = item.value as? Data,
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.artwork = image
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Mini Player Component

struct MiniPlayer: View {
    @ObservedObject var player: MusicPlayerViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Mini album art
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrackTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("SikeMusic")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Play/pause button
                Button(action: player.togglePlayPause) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2),
            alignment: .top
        )
    }
}

// MARK: - Full Player View

struct FullPlayerView: View {
    @ObservedObject var player: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSleepTimerSheet = false
    @State private var showingSpeedSheet = false
    @State private var showingMoreOptions = false
    @State private var currentArtwork: UIImage?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f1e")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "667eea"))
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("Now Playing")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("SikeMusic")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { showingSleepTimerSheet = true }) {
                            Label("Sleep Timer", systemImage: "moon")
                        }
                        
                        Button(action: { showingSpeedSheet = true }) {
                            Label("Speed Control", systemImage: "speedometer")
                        }
                        
                        Button(action: { showingMoreOptions = true }) {
                            Label("More Options", systemImage: "ellipsis")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Status indicators
                HStack(spacing: 15) {
                    if player.isShuffled {
                        Label("Shuffle", systemImage: "shuffle")
                            .font(.caption)
                            .foregroundColor(Color(hex: "667eea"))
                    }
                    
                    if player.repeatMode != .off {
                        Label(player.repeatMode.rawValue, systemImage: player.repeatMode.iconName)
                            .font(.caption)
                            .foregroundColor(Color(hex: "667eea"))
                    }
                    
                    if player.sleepTimerActive {
                        Label(player.sleepTimerDisplayText, systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if player.playbackSpeed != 1.0 {
                        Text("\(player.playbackSpeed, specifier: "%.1f")x")
                            .font(.caption)
                            .foregroundColor(Color(hex: "667eea"))
                    }
                }
                .padding(.horizontal)
                
                // Large album artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 300, height: 300)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    if let artwork = currentArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 300)
                            .clipped()
                            .cornerRadius(20)
                            .scaleEffect(player.isPlaying ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: player.isPlaying)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                            .scaleEffect(player.isPlaying ? 1.1 : 1.0)
                            .rotationEffect(.degrees(player.isPlaying ? 360 : 0))
                            .animation(
                                player.isPlaying ?
                                .linear(duration: 8).repeatForever(autoreverses: false) :
                                .default,
                                value: player.isPlaying
                            )
                    }
                }
                .onAppear {
                    loadCurrentTrackArtwork()
                }
                // FIXED: Updated onChange syntax for iOS 17+
                .onChange(of: player.currentTrackIndex) {
                    loadCurrentTrackArtwork()
                }
                
                // Track info
                VStack(spacing: 8) {
                    Text(player.currentTrackTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(player.trackInfo)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal)
                
                // Progress bar
                VStack(spacing: 10) {
                    ProgressBarView(player: player)
                    
                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 20) {
                    Button(action: player.toggleShuffle) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(player.isShuffled ? Color(hex: "667eea") : .white.opacity(0.6))
                    }
                    
                    Button(action: player.previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: player.togglePlayPause) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                                .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .offset(x: player.isPlaying ? 0 : 2)
                        }
                    }
                    .scaleEffect(player.isPlaying ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: player.isPlaying)
                    
                    Button(action: player.nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: player.cycleRepeatMode) {
                        Image(systemName: player.repeatMode.iconName)
                            .font(.title3)
                            .foregroundColor(player.repeatMode != .off ? Color(hex: "667eea") : .white.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                
                // Volume control (synced with system)
                VolumeControlView()
                    .padding(.horizontal)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSleepTimerSheet) {
            SleepTimerSheet(player: player)
        }
        .sheet(isPresented: $showingSpeedSheet) {
            PlaybackSpeedSheet(player: player)
        }
        .sheet(isPresented: $showingMoreOptions) {
            MoreOptionsSheet(player: player)
        }
    }
    
    private func loadCurrentTrackArtwork() {
        guard player.hasValidTrack else {
            currentArtwork = nil
            return
        }
        
        let currentTrack = player.tracks[player.currentTrackIndex]
        
        DispatchQueue.global(qos: .background).async {
            if let artwork = player.extractArtwork(from: currentTrack) {
                DispatchQueue.main.async {
                    self.currentArtwork = artwork
                }
            } else {
                DispatchQueue.main.async {
                    self.currentArtwork = nil
                }
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Bar Component

struct ProgressBarView: View {
    @ObservedObject var player: MusicPlayerViewModel
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                // Progress track
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * (isDragging ? dragValue : player.progressPercentage),
                        height: 6
                    )
                    .shadow(color: Color(hex: "667eea").opacity(0.5), radius: 4, x: 0, y: 0)
                
                // Draggable handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: geometry.size.width * (isDragging ? dragValue : player.progressPercentage) - 6)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragValue = min(max(0, value.location.x / geometry.size.width), 1)
                            }
                            .onEnded { value in
                                let finalValue = min(max(0, value.location.x / geometry.size.width), 1)
                                player.seek(to: finalValue)
                                isDragging = false
                            }
                    )
            }
        }
        .frame(height: 12)
    }
}

// MARK: - System Volume Control

struct VolumeControlView: View {
    @State private var systemVolume: Float = 0.5
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 15) {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 16))
                
                Slider(value: $systemVolume, in: 0...1) { editing in
                    if !editing {
                        setSystemVolume(systemVolume)
                    }
                }
                .accentColor(Color(hex: "667eea"))
                
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 16))
            }
            
            Text("\(Int(systemVolume * 100))%")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .onAppear {
            setupVolumeObserver()
        }
    }
    
    private func setupVolumeObserver() {
        systemVolume = AVAudioSession.sharedInstance().outputVolume
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { _ in
            systemVolume = AVAudioSession.sharedInstance().outputVolume
        }
    }
    
    private func setSystemVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                slider.value = volume
            }
        }
    }
}

// MARK: - App Icon Selector

struct AppIconSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIcon: String = "Default"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let availableIcons = [
        ("Default", "music.note"),
        ("Purple", "music.note.house.fill"),
        ("Blue", "airpods.pro"),
        ("Orange", "speaker.wave.3.fill"),
        ("Pink", "heart.fill"),
        ("Green", "leaf.fill"),
        ("Red", "flame.fill"),
        ("Dark", "moon.fill")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose App Icon")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("Note: This feature requires app icons to be added to your Xcode project.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(availableIcons, id: \.0) { icon in
                        IconPreview(
                            name: icon.0,
                            systemImage: icon.1,
                            isSelected: selectedIcon == icon.0,
                            onTap: {
                                selectedIcon = icon.0
                                changeAppIcon(to: icon.0 == "Default" ? nil : icon.0)
                            }
                        )
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            selectedIcon = UIApplication.shared.alternateIconName ?? "Default"
        }
        .alert("App Icon", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func changeAppIcon(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            alertMessage = "This device doesn't support alternate app icons."
            showingAlert = true
            return
        }
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Failed to change app icon: \(error.localizedDescription)"
                    showingAlert = true
                } else {
                    alertMessage = "App icon changed successfully!"
                    showingAlert = true
                }
            }
        }
    }
}

struct IconPreview: View {
    let name: String
    let systemImage: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                colors: iconGradientColors(for: name),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                        )
                    
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconGradientColors(for name: String) -> [Color] {
        switch name {
        case "Purple": return [Color(hex: "667eea"), Color(hex: "764ba2")]
        case "Blue": return [Color.blue, Color.cyan]
        case "Orange": return [Color.orange, Color.red]
        case "Pink": return [Color.pink, Color.purple]
        case "Green": return [Color.green, Color.mint]
        case "Red": return [Color.red, Color.orange]
        case "Dark": return [Color.black, Color.gray]
        default: return [Color(hex: "667eea"), Color(hex: "764ba2")]
        }
    }
}

// MARK: - Sleep Timer Sheet

struct SleepTimerSheet: View {
    @ObservedObject var player: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    let timerOptions = [0, 5, 10, 15, 30, 45, 60, 90, 120]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sleep Timer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                if player.sleepTimerActive {
                    VStack(spacing: 10) {
                        Text("Timer Active")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text(player.sleepTimerDisplayText)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(.orange)
                        
                        Button("Cancel Timer") {
                            player.cancelSleepTimer()
                            dismiss()
                        }
                        .foregroundColor(.red)
                        .padding()
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                        ForEach(timerOptions.dropFirst(), id: \.self) { minutes in
                            Button(action: {
                                player.setSleepTimer(minutes: minutes)
                                dismiss()
                            }) {
                                Text("\(minutes) min")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: "667eea"))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Playback Speed Sheet

struct PlaybackSpeedSheet: View {
    @ObservedObject var player: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Playback Speed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 15) {
                    Text("Current: \(player.playbackSpeed, specifier: "%.2f")x")
                        .font(.headline)
                        .foregroundColor(Color(hex: "667eea"))
                    
                    Slider(
                        value: $player.playbackSpeed,
                        in: 0.5...2.0,
                        step: 0.25
                    ) {
                        Text("Speed")
                    }
                    .accentColor(Color(hex: "667eea"))
                    .padding(.horizontal)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(speedOptions, id: \.self) { speed in
                        Button(action: {
                            player.playbackSpeed = speed
                        }) {
                            Text("\(speed, specifier: "%.2f")x")
                                .font(.caption)
                                .foregroundColor(player.playbackSpeed == speed ? .white : Color(hex: "667eea"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(player.playbackSpeed == speed ? Color(hex: "667eea") : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(hex: "667eea"), lineWidth: 1)
                                )
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - More Options Sheet

struct MoreOptionsSheet: View {
    @ObservedObject var player: MusicPlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Playback") {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Shuffle")
                        Spacer()
                        Toggle("", isOn: $player.isShuffled)
                    }
                    
                    HStack {
                        Image(systemName: player.repeatMode.iconName)
                        Text("Repeat")
                        Spacer()
                        Text(player.repeatMode.rawValue)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        player.cycleRepeatMode()
                    }
                }
                
                Section("Library") {
                    HStack {
                        Image(systemName: "music.note.list")
                        Text("Total Tracks")
                        Spacer()
                        Text("\(player.tracks.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if player.hasValidTrack {
                        HStack {
                            Image(systemName: "clock")
                            Text("Track Duration")
                            Spacer()
                            Text(formatTime(player.duration))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "folder.circle")
                        Text("Storage Used")
                        Spacer()
                        Text(calculateStorageUsed())
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Actions") {
                    Button(action: {
                        player.playbackSpeed = 1.0
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Speed to 1x")
                        }
                    }
                    .disabled(player.playbackSpeed == 1.0)
                    
                    if player.sleepTimerActive {
                        Button(action: {
                            player.cancelSleepTimer()
                        }) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.orange)
                                Text("Cancel Sleep Timer")
                            }
                        }
                    }
                }
            }
            .navigationTitle("More Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func calculateStorageUsed() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var totalSize: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
            .previewDisplayName("iPhone SE")
    }
}


