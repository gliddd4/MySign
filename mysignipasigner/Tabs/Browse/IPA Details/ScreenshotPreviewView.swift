//
//  ScreenshotPreviewView.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ScreenshotPreviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int
    @State private var showShareSheet = false
    @EnvironmentObject var themeAccent: Theme
    
    let screenshotURLs: [String]
    
    init(screenshotURLs: [String], initialIndex: Int = 0) {
        self.screenshotURLs = screenshotURLs
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    private func imageView(for phase: AsyncImagePhase, in geometry: GeometryProxy) -> some View {
        Group {
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.low)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
            case .failure(_):
                Text("Failed to load image")
                    .foregroundColor(.secondary)
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $currentIndex) {
                ForEach(screenshotURLs.indices, id: \.self) { index in
                    GeometryReader { geometry in
                        AsyncImage(url: URL(string: screenshotURLs[index])) { phase in
                            imageView(for: phase, in: geometry)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(currentIndex + 1) of \(screenshotURLs.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        ToastManager.shared.showToast.log("Clicked Done (toolbar) in Screenshot Preview")
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        ToastManager.shared.showToast.log("Clicked Share Screenshot")
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: screenshotURLs[currentIndex]) {
                ShareSheet(items: [url])
            }
        }
    }
}