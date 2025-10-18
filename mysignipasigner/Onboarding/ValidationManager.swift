//
//  ValidationManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

class ValidationManager {
    static let shared = ValidationManager()
    
    private init() {}
    
    // MARK: - Repository URL Validation
    func validateRepositoryURL(_ urlString: String) async -> Result<RepositoryFormat, ValidationError> {
        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL)
        }

        // Create a basic URLSession configuration
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.invalidStatusCode(httpResponse.statusCode))
            }

            // Remove BOM if present
            var cleanData = data
            let bom = Data([0xEF, 0xBB, 0xBF])
            if data.starts(with: bom) {
                cleanData = data.dropFirst(bom.count)
            }

            let decoder = JSONDecoder()
            do {
                let repository = try decoder.decode(RepositoryFormat.self, from: cleanData)
                guard !repository.name.isEmpty, !repository.identifier.isEmpty else {
                    return .failure(.missingRequiredFields)
                }
                return .success(repository)
            } catch let decodingError as DecodingError {
                // If decoding fails, include both the error and a snippet of the data for debugging
                let dataString = String(data: cleanData.prefix(500), encoding: .utf8) ?? "Could not decode data as UTF-8"
                return .failure(.decodingError(decodingError, httpResponse.mimeType ?? "unknown", dataString))
            }
        } catch {
            return .failure(.networkError(error))
        }
    }

    // MARK: - URL Input Validation
    func validateURLs(_ input: String) -> [String] {
        if input.hasPrefix("source[") {
            return [input]
        }

        return input
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { url in
                if url.isEmpty {
                    return false
                }

                guard !url.contains("["),
                      !url.contains("]"),
                      !url.contains("{"),
                      !url.contains("}"),
                      !url.contains("<"),
                      !url.contains(">"),
                      !url.contains("|"),
                      !url.contains("\\"),
                      let url = URL(string: url),
                      url.scheme != nil,
                      url.host != nil,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                    return false
                }
                return true
            }
    }

    func processURLInput(_ input: String) -> (processedText: String, removedDuplicates: [String]) {
        let lines = input.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var seenUrls = Set<String>()
        var removedDuplicates: [String] = [] // Store the actual duplicates

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Keep empty lines as they were to preserve formatting/spacing if needed
            if trimmedLine.isEmpty {
                 processedLines.append("")
                 continue
            }

            // Basic check if it looks like a URL fragment (contains '.')
            // More robust URL validation happens later if needed
            if trimmedLine.contains(".") {
                if !seenUrls.contains(trimmedLine) {
                    seenUrls.insert(trimmedLine)
                    processedLines.append(trimmedLine)
                } else {
                    // It's a duplicate
                    removedDuplicates.append(trimmedLine)
                }
            } else {
                // If it doesn't contain '.', treat it as non-URL text and keep it?
                // Or should non-URL lines be removed? Assuming keep for now.
                 processedLines.append(trimmedLine) // Keep lines that don't look like URLs
            }
        }

        return (processedLines.joined(separator: "\n"), removedDuplicates)
    }

    enum ValidationError: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidStatusCode(Int)
        case invalidFormat
        case decodingError(DecodingError, String, String)
        case missingRequiredFields
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL is not valid."
            case .invalidResponse:
                return "Received an invalid response from the server."
            case .invalidStatusCode(let code):
                return "Server returned an invalid status code: \(code)."
            case .invalidFormat:
                return "The data format is invalid or unexpected."
            case .decodingError(let error, let contentType, let dataSnippet):
                var description = "Failed to decode JSON (Content-Type: \(contentType)): \(error.localizedDescription)\n"
                description += "Context: \(error.detailedDescription)\n"
                description += "Data Snippet:\n\(dataSnippet)"
                return description
            case .missingRequiredFields:
                return "Required fields are missing or empty."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
}

extension DecodingError {
    var detailedDescription: String {
        switch self {
        case .typeMismatch(let type, let context):
            return "Type mismatch for type \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for type \(type) at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .keyNotFound(let key, let context):
            return "Key not found: '\(key.stringValue)' at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at path: \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
