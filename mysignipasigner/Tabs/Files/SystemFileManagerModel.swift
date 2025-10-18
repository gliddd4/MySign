import SwiftUI
import Foundation

// MARK: - FileDetails

struct FileDetails: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let owner: String
    let permissions: String
    let fileType: String
    
    init(path: String) {
        self.path = path
        self.name = URL(fileURLWithPath: path).lastPathComponent
        
        let fm = FileManager.default
        var isDir: ObjCBool = false
        self.isDirectory = fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        
        if let attrs = try? fm.attributesOfItem(atPath: path) {
            self.size = attrs[.size] as? Int64 ?? 0
            self.creationDate = attrs[.creationDate] as? Date
            self.modificationDate = attrs[.modificationDate] as? Date
            self.owner = attrs[.ownerAccountName] as? String ?? "Unknown"
            if let perm = attrs[.posixPermissions] as? NSNumber {
                self.permissions = String(format: "%o", perm.int16Value)
            } else {
                self.permissions = "Unknown"
            }
            self.fileType = attrs[.type] as? String ?? (isDirectory ? "Directory" : "File")
        } else {
            self.size = 0
            self.creationDate = nil
            self.modificationDate = nil
            self.owner = "Unknown"
            self.permissions = "Unknown"
            self.fileType = isDirectory ? "Directory" : "File"
        }
    }
}

// MARK: - Model

class SystemFileManagerModel: ObservableObject {
    @Published var currentPath: String = "/System"
    @Published var navigationStack: [String] = []
    @Published var files: [FileDetails] = []
    @Published var isLoading: Bool = false
    @Published var searchText: String = ""
    
    var filteredFiles: [FileDetails] {
        if searchText.isEmpty {
            return files
        } else {
            return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // MARK: Directory Loading
    
    func loadDirectory(path: String) {
        print("[SystemFileManagerModel] Loading directory: \(path)")
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var list: [FileDetails] = []
            
            let fm = FileManager.default
            
            // Check if path exists first
            var isDir: ObjCBool = false
            let pathExists = fm.fileExists(atPath: path, isDirectory: &isDir)
            
            if !pathExists {
                DispatchQueue.main.async {
                    self?.files = []
                    self?.isLoading = false
                }
                return
            }
            
            if !isDir.boolValue {
                DispatchQueue.main.async {
                    self?.files = []
                    self?.isLoading = false
                }
                return
            }
            
            do {
                let items = try fm.contentsOfDirectory(atPath: path)
                
                for entry in items {
                    let full = (path as NSString).appendingPathComponent(entry)
                    list.append(FileDetails(path: full))
                }
                list.sort { a, b in
                    if a.isDirectory && !b.isDirectory { return true }
                    if !a.isDirectory && b.isDirectory { return false }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                DispatchQueue.main.async {
                    self?.files = list
                    self?.currentPath = path
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.files = []
                    self?.isLoading = false
                }
            }
        }
    }
    
    func navigateToDirectory(path: String) {
        navigationStack.append(currentPath)
        loadDirectory(path: path)
    }
    
    func navigateBack() {
        guard !navigationStack.isEmpty else { return }
        let previousPath = navigationStack.removeLast()
        loadDirectory(path: previousPath)
    }
    
    func detectFileType(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "plist": 
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped, .uncached])
                if data.count >= 8 {
                    let signature = data.prefix(8)
                    if signature.starts(with: [98, 112, 108, 105, 115, 116]) {
                        return "Binary Property List"
                    }
                }
                return "Property List"
            } catch {
                return "Property List"
            }
        case "xml": return "XML File"
        case "html", "htm": return "HTML File"
        case "txt", "log", "md": return "Text File"
        case "png", "jpg", "jpeg", "gif", "heic": return "Image"
        case "pdf": return "PDF Document"
        case "c", "h", "swift", "m", "cpp", "php", "js", "css": return "Source Code"
        case "zip", "rar", "tar", "gz": return "Archive"
        case "json": return "JSON File"
        case "mp3": return "MP3 Audio File"
        case "m4a", "aac": return "AAC Audio File"
        case "wav": return "WAV Audio File"
        case "caf": return "CAF Audio File"
        case "aiff", "aif": return "AIFF Audio File"
        case "flac": return "FLAC Audio File"
        default:
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return "Directory"
            }
            return "Unknown File Type"
        }
    }
    
    func getFileIcon(for file: FileDetails) -> String {
        if file.isDirectory { return "folder.fill" }
        switch URL(fileURLWithPath: file.path).pathExtension.lowercased() {
        case "plist": return "doc.text.fill"
        case "xml": return "chevron.left.forwardslash.chevron.right"
        case "html", "htm": return "globe"
        case "txt", "log", "md": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "heic": return "photo"
        case "pdf": return "doc.fill"
        case "c", "h", "swift", "m", "cpp", "php", "js", "css": return "chevron.left.slash.chevron.right"
        case "zip", "rar", "tar", "gz": return "archivebox.fill"
        case "json": return "curlybraces"
        case "mp3", "m4a", "aac", "wav", "caf", "aiff", "aif", "flac": return "music.note"
        default: return "doc.fill"
        }
    }
    
    func formattedFileSize(size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func readFileContent(path: String) -> (content: String?, error: String?) {
        if path.isEmpty { return (nil, "Invalid file path") }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
        
            if detectFileType(for: path) == "Binary Property List" {
                do {
                    let plistObj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                    let xmlData = try PropertyListSerialization.data(fromPropertyList: plistObj, format: .xml, options: 0)
                    
                    if let xmlString = String(data: xmlData, encoding: .utf8) {
                        return (xmlString, nil)
                    } else {
                        return (nil, "Failed to convert binary plist to readable format")
                    }
                } catch {
                    return (nil, "Error processing plist: \(error.localizedDescription)")
                }
            }
            
            var isText = true
            let sampleData = data.prefix(min(1024, data.count))
            for byte in sampleData {
                if (byte < 32 || byte > 126) && !([9, 10, 13].contains(byte)) {
                    isText = false
                    break
                }
            }
            
            if isText {
                if let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                    return (content, nil)
                }
            }
            
            return (nil, "Binary file - cannot display content")
            
        } catch {
            return (nil, "Error reading file: \(error.localizedDescription)")
        }
    }
    
    func loadImage(from path: String) -> UIImage? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return UIImage(contentsOfFile: path)
    }
    
    func generateHexDump(for path: String, maxBytes: Int = 4096) -> String? {        
        do {
            let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            defer { fileHandle.closeFile() }
            
            let data = fileHandle.readData(ofLength: maxBytes)
            let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 ?? 0
            
            var hexDump = ""
            var ascii = ""
            var line = ""
            
            for (index, byte) in data.enumerated() {
                let hex = String(format: "%02X ", byte)
                line += hex
                
                let char = (byte >= 32 && byte <= 126) ? String(format: "%c", byte) : "."
                ascii += char
                
                if (index + 1) % 16 == 0 || index == data.count - 1 {
                    while line.count < 16 * 3 {
                        line += "   "
                    }
                    
                    let address = String(format: "%08X", (index / 16) * 16)
                    hexDump += "\(address)  \(line) |" + ascii + "|\n"
                    
                    line = ""
                    ascii = ""
                }
            }
        
            if fileSize > Int64(maxBytes) {
                hexDump += "\n... (showing first \(maxBytes) bytes of \(fileSize) total bytes)"
            }
            
            return hexDump
            
        } catch {
            return "Error generating hex dump: \(error.localizedDescription)"
        }
    }
}