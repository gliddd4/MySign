//
//  Sorting.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

struct AppSorting {
    static func sortApps(_ apps: [App], by option: AppSortOption, searchText: String = "") -> [App] {
        let filteredApps = searchText.isEmpty ? apps : apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText)
        }
        
        if option == .default {
            return filteredApps
        }
        
        return filteredApps.sorted { a, b in
            switch option {
            case .aToZ:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .zToA:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
            case .latest:
                if let aDateString = a.versionDate, let bDateString = b.versionDate,
                   let aDate = parseDate(aDateString), let bDate = parseDate(bDateString) {
                    return aDate.compare(bDate) == .orderedDescending
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .oldest:
                if let aDateString = a.versionDate, let bDateString = b.versionDate,
                   let aDate = parseDate(aDateString), let bDate = parseDate(bDateString) {
                    return aDate.compare(bDate) == .orderedAscending
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .default:
                return false
            }
        }
    }
    
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd HH:mm:ss"]
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

enum AppSortOption: String, CaseIterable {
    case `default` = "Default"
    case aToZ = "A to Z"
    case zToA = "Z to A"
    case latest = "Latest"
    case oldest = "Oldest"
}

enum RepositorySortOption: String, CaseIterable {
    case aToZ = "A to Z"
    case zToA = "Z to A"
    case mostApps = "Most Apps"
    case leastApps = "Least Apps"
}