//
//  FileContentView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct FileContentView: View {
    let file: FileDetails
    @ObservedObject var viewModel: SystemFileManagerModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showCopiedPathToast: Bool = false
    @ObservedObject private var themeManager = Theme.shared
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                contentView
            }
            
            if showCopiedPathToast {
                VStack {
                    Spacer()
                    Text("Path copied to clipboard")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeManager.accentColor.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                        .padding(.bottom, 16)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCopiedPathToast = false
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Close")
                    .foregroundColor(themeManager.accentColor)
            }
            
            Spacer()
            
            Text(file.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                UIPasteboard.general.string = file.path
                withAnimation {
                    showCopiedPathToast = true
                }
            }) {
                Text("Copy Path")
                    .foregroundColor(themeManager.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    private var contentView: some View {
        let fileType = viewModel.detectFileType(for: file.path)
        
        if isAudioFile(path: file.path) {
            return AnyView(AudioPlayerView(filePath: file.path, fileName: file.name))
        }
        
        switch fileType {
        case "Image":
            return AnyView(imageContentView)
        case "Property List", "Binary Property List":
            return AnyView(plistContentView)
        case "Text File", "XML File", "HTML File", "Source Code", "JSON File":
            return AnyView(textContentView)
        default:
            return AnyView(hexContentView)
        }
    }
    
    private var imageContentView: some View {
        VStack {
            if let image = viewModel.loadImage(from: file.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                errorView(message: "Failed to load image")
            }
            
            Text("Size: \(viewModel.formattedFileSize(size: file.size))")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom)
        }
    }
    
    private var plistContentView: some View {
        VStack {
            let result = viewModel.readFileContent(path: file.path)
            
            if let content = result.content {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let error = result.error {
                errorView(message: error)
            } else {
                errorView(message: "Unknown error loading plist content")
            }
        }
    }
    
    private var textContentView: some View {
        VStack {
            let result = viewModel.readFileContent(path: file.path)
            
            if let content = result.content {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let error = result.error {
                errorView(message: error)
            } else {
                errorView(message: "Unknown error loading text content")
            }
        }
    }
    
    private var hexContentView: some View {
        VStack {
            if let hexDump = viewModel.generateHexDump(for: file.path) {
                ScrollView {
                    Text(hexDump)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                errorView(message: "Failed to generate hex dump")
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
                .padding()
            
            Text(message)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
}

struct AudioPlayerView: View {
    let filePath: String
    let fileName: String
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @ObservedObject private var themeManager = Theme.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text(fileName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 100)
                
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(isPlaying ? themeManager.accentColor : .gray)
            }
            .padding(.horizontal)
            
            Button(action: {
                togglePlayback()
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(themeManager.accentColor)
            }
            .padding()
            
            if let audioPlayer = audioPlayer {
                VStack(spacing: 6) {
                    HStack {
                        Text("Duration:")
                            .font(.caption)
                            .foregroundColor(themeManager.accentColor)
                        
                        Spacer()
                        
                        Text(formatTime(audioPlayer.duration))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                )
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            stopPlayback()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Audio Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func setupAudioPlayer() {
        do {
            let url = URL(fileURLWithPath: filePath)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer?.prepareToPlay()
        } catch {
            errorMessage = "Failed to load audio: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        
        isPlaying.toggle()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

public func isAudioFile(path: String) -> Bool {
    let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
    let audioExtensions = ["mp3", "m4a", "aac", "wav", "caf", "aiff", "aif", "flac"]
    return audioExtensions.contains(fileExtension)
}