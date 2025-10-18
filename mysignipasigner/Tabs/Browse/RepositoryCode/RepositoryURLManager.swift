// 
//  RepositoryURLManager.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import Foundation

class RepositoryURLManager {
    static let shared = RepositoryURLManager()
    private let userDefaultsKey = "repositories_urls"
    
    private let defaultURLs = [
        "https://ipa.cypwn.xyz/cypwn.json"
    ]
    
    var repositoryURLs: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? defaultURLs
        }
        set {
            let uniqueURLs = Array(Set(newValue))
            UserDefaults.standard.set(uniqueURLs, forKey: userDefaultsKey)
        }
    }
    
    private init() {
        if UserDefaults.standard.array(forKey: userDefaultsKey) == nil {
            UserDefaults.standard.set(defaultURLs, forKey: userDefaultsKey)
        }
    }
}
