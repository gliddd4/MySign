//
//  NukeImage.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI
import Nuke

struct NukeImage<Content: View>: View {
    let url: URL
    let content: (ImageState) -> Content
    @StateObject private var imageLoader = ImageLoader()
    
    init(url: URL, @ViewBuilder content: @escaping (ImageState) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        content(imageLoader.state)
            .onAppear {
                imageLoader.load(url: url)
            }
            .onDisappear {
                imageLoader.cancel()
            }
    }
}
