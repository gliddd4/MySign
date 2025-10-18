//
//  ImagePreview.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct ImagePreview: View {
    var currentIndex: Int
    let images: [FileItem]
    @Binding var isPresented: Bool
    @State private var showShareSheet = false
    @State private var selectedIndex: Int
    
    init(currentIndex: Int, images: [FileItem], isPresented: Binding<Bool>) {
        self.currentIndex = currentIndex
        self.images = images
        self._isPresented = isPresented
        self._selectedIndex = State(initialValue: currentIndex)
    }
    
    private func isInRepositoryIconsFolder(url: URL) -> Bool {
        return url.path.contains("Repository Icons")
    }
    
    private func imageView(for phase: AsyncImagePhase, in geometry: GeometryProxy, url: URL) -> some View {
        Group {
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .interpolation(.low)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .if(isInRepositoryIconsFolder(url: url)) { view in
                        view.clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
            case .failure(_):
                Text("Failed to load image")
            case .empty:
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedIndex) {
                ForEach(images.indices, id: \.self) { index in
                    GeometryReader { geometry in
                        AsyncImage(url: images[index].url) { phase in
                            imageView(for: phase, in: geometry, url: images[index].url)
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
                    Text("\(selectedIndex + 1) of \(images.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [images[selectedIndex].url])
        }
    }
}