//
//  ScreenshotGallery.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ScreenshotGallery: View {
    let screenshotURLs: [String]
    @State private var isScreenshotPreviewPresented = false
    @State private var selectedScreenshotIndex = 0
    @EnvironmentObject var themeAccent: Theme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(screenshotURLs.count) SCREENSHOT\(screenshotURLs.count == 1 ? "" : "S")")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Screenshot Gallery
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(screenshotURLs.indices, id: \.self) { index in
                        let url = screenshotURLs[index]
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 400)
                                    .overlay {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    }
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(
                                        maxWidth: UIScreen.main.bounds.width - 64,
                                        maxHeight: 400
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                                    }
                                    .onTapGesture {
                                        ToastManager.shared.showToast.log("Clicked Screenshot \(index + 1)")
                                        selectedScreenshotIndex = index
                                        isScreenshotPreviewPresented = true
                                    }
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 400)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                    }
                            @unknown default:
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 200, height: 400)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.secondary)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .popover(isPresented: $isScreenshotPreviewPresented) {
            ScreenshotPreviewView(
                screenshotURLs: screenshotURLs,
                initialIndex: selectedScreenshotIndex
            )
            .environmentObject(themeAccent)
        }
    }
}