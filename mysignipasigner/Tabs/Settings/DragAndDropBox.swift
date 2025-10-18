import SwiftUI
import UniformTypeIdentifiers

struct DragAndDropBox: View {
    let onFileSelected: (URL) -> Void
    
    @State private var isTargeted = false
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundColor(isTargeted ? .accentColor : .gray)
                .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    Group {
                        if isTargeted {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Drag and drop a wallpaper or upload from files")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                    }
                )
                .onTapGesture {
                    showingFilePicker = true
                }
                .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                    guard let provider = providers.first else {
                        return false
                    }
                    
                    _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.image.identifier) { (url, isSuccess, error) in
                        if let url = url {
                            DispatchQueue.main.async {
                                onFileSelected(url)
                            }
                        }
                    }
                    return true
                }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onFileSelected(url)
                }
            case .failure(let error):
                ToastManager.shared.showToast.error("Failed to select file: \(error.localizedDescription)")
            }
        }
    }
}