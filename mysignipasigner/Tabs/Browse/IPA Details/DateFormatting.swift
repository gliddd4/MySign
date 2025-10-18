//
//  DateFormatting.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

struct DateFormatting {
    static func formatRelativeDate(_ date: Date) -> String {
        let useFullYearFormat = UserDefaults.standard.bool(forKey: "browse_useFullYearFormat")
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate days difference
        let daysDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        
        if daysDiff == 0 {
            return "Today"
        } else if daysDiff == 1 {
            return "Yesterday"
        } else if daysDiff < 7 {
            return "\(daysDiff) Days"
        } else if daysDiff < 30 {
            let weeks = daysDiff / 7
            let remainingDays = daysDiff % 7
            
            if remainingDays == 0 {
                return weeks == 1 ? "1 Week" : "\(weeks) Weeks"
            } else {
                let weeksText = weeks == 1 ? "1 Week" : "\(weeks) Weeks"
                let daysText = remainingDays == 1 ? "1 Day" : "\(remainingDays) Days"
                return "\(weeksText) & \(daysText)"
            }
        } else if daysDiff < 365 {
            let months = daysDiff / 30
            let remainingDays = daysDiff % 30
            
            if remainingDays == 0 {
                return months == 1 ? "1 Month" : "\(months) Months"
            } else {
                let monthsText = months == 1 ? "1 Month" : "\(months) Months"
                let daysText = remainingDays == 1 ? "1 Day" : "\(remainingDays) Days"
                return "\(monthsText) & \(daysText)"
            }
        } else {
            let years = daysDiff / 365
            let remainingDays = daysDiff % 365
             
            if remainingDays == 0 {
                if useFullYearFormat {
                    return years == 1 ? "1 year" : "\(years) years"
                } else {
                    return years == 1 ? "1yr" : "\(years)yrs"
                }
            } else {
                let yearsText: String
                if useFullYearFormat {
                    yearsText = years == 1 ? "1 year" : "\(years) years"
                } else {
                    yearsText = years == 1 ? "1yr" : "\(years)yrs"
                }
                let daysText = remainingDays == 1 ? "1 Day" : "\(remainingDays) Days"
                return "\(yearsText) & \(daysText)"
            }
        }
    }
    
    static func parseDate(_ dateString: String) -> Date? {
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