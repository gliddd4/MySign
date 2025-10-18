//
//  NewsItem.swift
//  mysignipasigner
//
//  Created by AI Assistant
//

import Foundation

struct NewsItem: Codable, Identifiable, Hashable {
    let title: String
    let identifier: String
    let caption: String?
    let tintColor: String?
    let imageURL: String?
    let appID: String?
    let date: String?
    let url: String?
    let notify: Bool?
    
    var id: String { identifier }
    
    var parsedDate: Date? {
        guard let date = date else { return nil }
        
        // Try multiple date formats commonly used in repository news
        let formatters = [
            // ISO 8601 with timezone
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            // ISO 8601 without timezone
            "yyyy-MM-dd'T'HH:mm:ss",
            // Date only
            "yyyy-MM-dd",
            // Alternative formats
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        
        let isoFormatter = ISO8601DateFormatter()
        if let parsedDate = isoFormatter.date(from: date) {
            return parsedDate
        }
        
        for formatString in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = formatString
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            if let parsedDate = formatter.date(from: date) {
                return parsedDate
            }
        }
        
        return nil
    }
    
    var formattedDate: String? {
        guard let parsedDate = parsedDate else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: parsedDate, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "1 day ago"
            } else if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
            } else if days < 365 {
                let months = days / 30
                return months == 1 ? "1 month ago" : "\(months) months ago"
            } else {
                let years = days / 365
                return years == 1 ? "1 year ago" : "\(years) years ago"
            }
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// NewsRepository struct - avoiding circular references by not importing RepositoryFormat here
struct NewsRepository {
    let repositoryName: String
    let repositoryIdentifier: String
    let repositoryIconURL: String?
    let news: [NewsItem]
}