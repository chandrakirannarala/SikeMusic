//
//  ContentView.swift
//  SikeMusic
//
//  Optimized for iPhone SE 2 and better performance
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = MusicPlayerViewModel()
    @State private var isImporting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f1e")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: adaptiveSpacing(for: geometry.size.height)) {
                        // Header
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
                            .padding(.top, 20)
                        
                        // Album Art - Adaptive size for smaller screens
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: albumArtSize(for: geometry), height: albumArtSize(for: geometry))
                                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            if player.hasValidTrack {
                                Image(systemName: "music.note")
                                    .font(.system(size: albumArtSize(for: geometry) * 0.35))
                                    .foregroundColor(.white.opacity(0.8))
                                    .scaleEffect(player.isPlaying ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: player.isPlaying)
                            } else {
                                VStack {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: albumArtSize(for: geometry) * 0.25))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("No Music")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        
                        // Track Info
                        VStack(spacing: 8) {
                            Text(player.currentTrackTitle)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                            
                            Text(player.trackInfo)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal)
                        
                        // Progress Bar - Only show if track is loaded
                        if player.hasValidTrack {
                            VStack(spacing: 10) {
                                GeometryReader { progressGeometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 4)
                                        
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: progressGeometry.size.width * player.progressPercentage, height: 4)
                                    }
                                    .onTapGesture { location in
                                        let progress = location.x / progressGeometry.size.width
                                        player.seek(to: progress)
                                    }
                                }
                                .frame(height: 4)
                                
                                HStack {
                                    Text(formatTime(player.currentTime))
                                    Spacer()
                                    Text(formatTime(player.duration))
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal)
                        }
                        
                        // Playback Controls
                        HStack(spacing: controlSpacing(for: geometry)) {
                            Button(action: player.previousTrack) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: controlIconSize(for: geometry)))
                                    .foregroundColor(player.hasValidTrack ? .white : .white.opacity(0.3))
                            }
                            .disabled(!player.hasValidTrack)
                            
                            Button(action: player.togglePlayPause) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: player.hasValidTrack ?
                                                [Color(hex: "667eea"), Color(hex: "764ba2")] :
                                                [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: playButtonSize(for: geometry), height: playButtonSize(for: geometry))
                                    
                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: playButtonSize(for: geometry) * 0.4))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(!player.hasValidTrack)
                            
                            Button(action: player.nextTrack) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: controlIconSize(for: geometry)))
                                    .foregroundColor(player.hasValidTrack ? .white : .white.opacity(0.3))
                            }
                            .disabled(!player.hasValidTrack)
                        }
                        
                        // Volume Control - Only show if track is loaded
                        if player.hasValidTrack {
                            HStack(spacing: 15) {
                                Image(systemName: "speaker.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                                
                                Slider(value: $player.volume, in: 0...1)
                                    .accentColor(Color(hex: "667eea"))
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal)
                        }
                        
                        // Add Music Button
                        Button(action: { isImporting = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text(player.tracks.isEmpty ? "Add Your First Song" : "Add More Music")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [
                .audio,
                UTType(filenameExtension: "mp3") ?? .audio,
                UTType(filenameExtension: "m4a") ?? .audio,
                UTType(filenameExtension: "wav") ?? .audio,
                UTType(filenameExtension: "aiff") ?? .audio
            ],
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
    
    // MARK: - Adaptive Layout Functions
    
    private func adaptiveSpacing(for height: CGFloat) -> CGFloat {
        return height < 700 ? 15 : 25 // Smaller spacing for iPhone SE
    }
    
    private func albumArtSize(for geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        let screenWidth = geometry.size.width
        let minDimension = min(screenWidth, screenHeight)
        
        if screenHeight < 700 { // iPhone SE 2 and similar
            return min(minDimension * 0.6, 200)
        } else {
            return min(minDimension * 0.7, 280)
        }
    }
    
    private func controlIconSize(for geometry: GeometryProxy) -> CGFloat {
        return geometry.size.height < 700 ? 25 : 30
    }
    
    private func playButtonSize(for geometry: GeometryProxy) -> CGFloat {
        return geometry.size.height < 700 ? 60 : 70
    }
    
    private func controlSpacing(for geometry: GeometryProxy) -> CGFloat {
        return geometry.size.height < 700 ? 30 : 40
    }
    
    func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Color Extension for Hex Colors
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

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone SE (3rd generation)")
        ContentView()
            .previewDevice("iPhone 14")
    }
}


